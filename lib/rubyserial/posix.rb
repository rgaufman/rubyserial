# frozen_string_literal: true

# Copyright (c) 2014-2016 The Hybrid Group

require 'English'
require 'active_support/core_ext/object/blank'
require 'semantic_logger'

class Serial
  include SemanticLogger::Loggable

  def initialize(address, baude_rate = 9600, data_bits = 8, parity = :none, stop_bits = 1)
    file_opts = RubySerial::Posix::O_RDWR | RubySerial::Posix::O_NOCTTY | RubySerial::Posix::O_NONBLOCK
    @fd = RubySerial::Posix.open(address, file_opts)

    raise RubySerial::Error, RubySerial::Posix::ERROR_CODES[FFI.errno] if @fd == -1

    @open = true
    @read_buffer = [] # Instance-level buffer to preserve data between reads

    fl = RubySerial::Posix.fcntl(@fd, RubySerial::Posix::F_GETFL, :int, 0)
    raise RubySerial::Error, RubySerial::Posix::ERROR_CODES[FFI.errno] if fl == -1

    err = RubySerial::Posix.fcntl(@fd, RubySerial::Posix::F_SETFL, :int, ~RubySerial::Posix::O_NONBLOCK & fl)
    raise RubySerial::Error, RubySerial::Posix::ERROR_CODES[FFI.errno] if err == -1

    @config = build_config(baude_rate, data_bits, parity, stop_bits)

    err = RubySerial::Posix.tcsetattr(@fd, RubySerial::Posix::TCSANOW, @config)
    return unless err == -1

    raise RubySerial::Error, RubySerial::Posix::ERROR_CODES[FFI.errno]
  end

  def closed?
    !@open
  end

  def close
    err = RubySerial::Posix.close(@fd)
    raise RubySerial::Error, RubySerial::Posix::ERROR_CODES[FFI.errno] if err == -1

    @open = false
  end

  def write(data, timeout: 30)
    data = data.to_s
    n = 0
    start_time = Time.now
    io = IO.for_fd(@fd, mode: 'w', autoclose: false)

    while data.size > n
      elapsed = Time.now - start_time
      remaining = timeout - elapsed
      raise RubySerial::Error, "Write timeout after #{timeout}s (#{n}/#{data.size} bytes written)" if remaining <= 0

      # Wait for FD to be writable before attempting the write
      unless IO.select(nil, [io], nil, remaining)
        raise RubySerial::Error, "Write timeout after #{timeout}s (#{n}/#{data.size} bytes written)"
      end

      buff = FFI::MemoryPointer.from_string(data[n..].to_s)
      i = RubySerial::Posix.write(@fd, buff, buff.size - 1)
      raise RubySerial::Error, RubySerial::Posix::ERROR_CODES[FFI.errno] if i == -1

      n += i
    end

    # return number of bytes written
    n
  end

  def read(size)
    buff = FFI::MemoryPointer.new :char, size
    i = RubySerial::Posix.read(@fd, buff, size)
    raise RubySerial::Error, RubySerial::Posix::ERROR_CODES[FFI.errno] if i == -1

    buff.get_bytes(0, i)
  end

  def getbyte
    buff = FFI::MemoryPointer.new :char, 1
    i = RubySerial::Posix.read(@fd, buff, 1)
    raise RubySerial::Error, RubySerial::Posix::ERROR_CODES[FFI.errno] if i == -1

    if i.zero?
      nil
    else
      buff.get_bytes(0, 1).bytes.first
    end
  end

  def gets(sep: "\n", limit: nil)
    if block_given?
      loop do
        yield(get_until_sep(sep:, limit:))
      end
    else
      get_until_sep(sep:, limit:)
    end
  end

  def readline(sep: "\n", limit: nil, timeout: 60)
    # Pass timeout directly to get_until_sep instead of using dangerous Timeout.timeout
    # which can interrupt system calls mid-operation and corrupt buffer state
    if block_given?
      loop do
        yield(get_until_sep(sep:, limit:, timeout:))
      end
    else
      get_until_sep(sep:, limit:, timeout:)
    end
  end

  # Reliable readline for protocol-based communication (e.g., Texecom alarms)
  # Reads one character at a time until terminator or keyword found
  # Uses instance-level buffer to preserve partial reads
  def readline_chunked(terminators: ["\n"], timeout: 5, stop_keywords: [], chomp_separator: true)
    start_time = Time.now
    separators = Array(terminators)
    stop_keywords = Array(stop_keywords)
    consecutive_empty_reads = 0

    logger.debug "readline_chunked: start (buffer has #{@read_buffer.size} bytes from previous read)"

    loop do
      elapsed = Time.now - start_time

      # Reliable timeout check - return buffer contents if exceeded
      if elapsed > timeout
        # Even on timeout, drain any immediately available trailing bytes
        logger.info "readline_chunked: TIMEOUT after #{elapsed.round(2)}s, draining trailing bytes..."
        trailing_bytes = 0
        lookahead_bytes = []
        max_drain_attempts = 10 # Quick drain on timeout

        max_drain_attempts.times do
          byte = getbyte
          break if byte.nil?

          if [13, 10, 32, 9].include?(byte)
            @read_buffer << byte
            trailing_bytes += 1
          else
            # Non-whitespace byte belongs to next response
            lookahead_bytes << byte
            logger.info "readline_chunked: preserved lookahead byte #{byte.chr.inspect} for next read"
            break
          end
        end

        raw_buffer = buffer_to_string
        result = raw_buffer
        if chomp_separator
          separators.each { |sep| result = result.chomp(sep) }
          result = result.chomp("\r")
        end
        logger.info "readline_chunked: TIMEOUT drained #{trailing_bytes} trailing bytes"
        logger.info "  Raw buffer: #{raw_buffer.inspect} (#{raw_buffer.bytes.map { |b| "0x#{b.to_s(16).upcase.rjust(2, '0')}" }.join(' ')})"
        logger.info "  Cleaned result: #{result.inspect} (#{result.bytesize} bytes)"
        @read_buffer = lookahead_bytes # Preserve lookahead bytes for next read
        logger.info "readline_chunked: buffer cleared, #{@read_buffer.size} lookahead bytes preserved" if @read_buffer.any?
        return result
      end

      # Read one byte at a time for reliability
      byte = getbyte

      if byte.nil?
        consecutive_empty_reads += 1
        # Progressive backoff to reduce CPU usage
        sleep_time = if consecutive_empty_reads < 10
                       0.01  # 10ms for first 10 attempts
                     elsif consecutive_empty_reads < 50
                       0.02  # 20ms for next 40 attempts
                     else
                       0.05  # 50ms after that
                     end
        sleep(sleep_time)
      else
        @read_buffer << byte
        consecutive_empty_reads = 0
        # Log byte with hex code and printable character (debug level for routine operations)
        char_repr = byte.chr.inspect
        hex_repr = "0x#{byte.to_s(16).upcase.rjust(2, '0')}"
        buffer_str = buffer_to_string.inspect
        logger.debug "readline_chunked: read byte #{char_repr} (#{hex_repr}), buffer: #{@read_buffer.size} bytes, content: #{buffer_str}"
      end

      # Check if buffer ends with any separator
      separator_found = separators.any? do |sep|
        @read_buffer.last(sep.bytesize) == sep.bytes
      end

      # Check if buffer ends with a keyword (OK or ERROR)
      keyword_found = stop_keywords.any? do |keyword|
        @read_buffer.last(keyword.bytesize) == keyword.bytes
      end

      # Return when we find a terminator
      if separator_found || keyword_found
        # IMPORTANT: After finding the primary terminator, we need to consume any
        # trailing line terminators (\r\n) to prevent them from polluting the next read.
        # The Texecom protocol often sends responses like "OK/\r\n" where we detect the "/"
        # but leave "\r\n" in the OS buffer, causing the next command to read stale data.

        terminator_type = separator_found ? "separator" : "keyword"
        logger.debug "readline_chunked: found #{terminator_type}, consuming trailing terminators..."

        # Drain immediately available trailing bytes (don't wait/sleep)
        # This consumes trailing \r\n without adding latency
        trailing_bytes = 0
        lookahead_bytes = []
        max_drain_attempts = 20 # Limit drain attempts to prevent hanging

        max_drain_attempts.times do
          byte = getbyte
          if byte.nil?
            # No more bytes immediately available, stop draining
            break
          elsif [13, 10, 32, 9].include?(byte) # \r, \n, space, tab
            @read_buffer << byte
            trailing_bytes += 1
            logger.debug "readline_chunked: consumed trailing byte #{byte.chr.inspect} (0x#{byte.to_s(16).upcase.rjust(2, '0')})"
          else
            # Found a non-whitespace byte, this belongs to next response
            # Keep it separate so we don't clear it with the current response
            lookahead_bytes << byte
            logger.warn "readline_chunked: found non-whitespace byte #{byte.chr.inspect} during drain, saving for next read"
            break
          end
        end

        raw_buffer = buffer_to_string
        result = raw_buffer
        if chomp_separator
          separators.each { |sep| result = result.chomp(sep) }
          result = result.chomp("\r")
        end
        logger.debug "readline_chunked: complete (#{terminator_type}, drained #{trailing_bytes} trailing bytes) in #{elapsed.round(2)}s"
        logger.debug "  Raw buffer: #{raw_buffer.inspect} (#{raw_buffer.bytes.map { |b| "0x#{b.to_s(16).upcase.rjust(2, '0')}" }.join(' ')})"
        logger.debug "  Cleaned result: #{result.inspect} (#{result.bytesize} bytes)"

        # Clear buffer but preserve any lookahead bytes for next read
        @read_buffer = lookahead_bytes
        logger.debug "readline_chunked: buffer cleared, #{@read_buffer.size} lookahead bytes preserved" if @read_buffer.any?

        return result
      end
    end
  end

  private

  def get_until_sep(sep: nil, limit: nil, timeout: 5, chunk_size: 1, chomp_separator: false, stop_on_keywords: [])
    buffer = chunk_size > 1 ? '' : []
    start_time = Time.now
    consecutive_empty_reads = 0
    separators = Array(sep) # Support both single separator and array

    loop do
      # Check timeout
      if timeout && (Time.now - start_time) > timeout
        raise RubySerial::Error, "Timeout waiting for data (expected separator: #{sep.inspect})"
      end

      # Read data - either byte-by-byte or in chunks
      if chunk_size > 1
        chunk = read(chunk_size)
        data_received = chunk.present?
        buffer += chunk if data_received
      else
        current_byte = getbyte
        data_received = !current_byte.nil?
        buffer << current_byte if data_received
      end

      if data_received
        consecutive_empty_reads = 0
      else
        consecutive_empty_reads += 1
        # Sleep to prevent CPU spinning when no data is available
        # Use longer sleeps for better CPU efficiency
        if consecutive_empty_reads < 10
          sleep(0.005)  # 5ms for first 10 attempts
        elsif consecutive_empty_reads < 50
          sleep(0.01)   # 10ms for next 40 attempts
        else
          sleep(0.02)   # 20ms after that
        end
      end

      # Check if we've found any of the separators (avoid O(n²) string conversion)
      separator_reached = separators.any? do |separator|
        if chunk_size > 1
          buffer.end_with?(separator)
        else
          separator_size = separator.bytesize
          buffer.last(separator_size) == separator.bytes
        end
      end

      # Check for stop keywords (only convert to string once if needed)
      keyword_found = if stop_on_keywords.any? && data_received
                        current_string = chunk_size > 1 ? buffer : buffer.map(&:chr).join
                        stop_on_keywords.any? { |keyword| current_string.include?(keyword) }
                      else
                        false
                      end

      # Check if we have a limit and it's been reached
      limit_reached = limit.present? && (chunk_size > 1 ? buffer.size : buffer.size) >= limit

      # If we have data and many empty reads, break
      has_data_and_stalled = !buffer.empty? && consecutive_empty_reads > 100

      # Stop reading if any condition is true
      break if separator_reached || keyword_found || limit_reached || has_data_and_stalled
    end

    # Convert to string if needed
    result = chunk_size > 1 ? buffer : buffer.map(&:chr).join

    # Chomp separators if requested
    separators.each { |separator| result = result.chomp(separator) } if chomp_separator

    result
  end

  def build_config(baude_rate, data_bits, parity, stop_bits)
    config = RubySerial::Posix::Termios.new

    config[:c_iflag]  = RubySerial::Posix::IGNPAR
    config[:c_ispeed] = RubySerial::Posix::BAUDE_RATES[baude_rate]
    config[:c_ospeed] = RubySerial::Posix::BAUDE_RATES[baude_rate]
    config[:c_cflag]  = RubySerial::Posix::DATA_BITS[data_bits] |
                        RubySerial::Posix::CREAD |
                        RubySerial::Posix::CLOCAL |
                        RubySerial::Posix::PARITY[parity] |
                        RubySerial::Posix::STOPBITS[stop_bits]

    # Masking in baud rate on OS X would corrupt the settings.
    config[:c_cflag] = config[:c_cflag] | RubySerial::Posix::BAUDE_RATES[baude_rate] if RubySerial::ON_LINUX

    config[:cc_c][RubySerial::Posix::VMIN] = 0

    config
  end

  # Helper method to convert byte buffer to string
  def buffer_to_string
    @read_buffer.map(&:chr).join
  end
end
