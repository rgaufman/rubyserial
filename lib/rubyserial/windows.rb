# frozen_string_literal: true

# Copyright (c) 2014-2016 The Hybrid Group

require 'English'
class Serial
  def initialize(address, baude_rate = 9600, data_bits = 8, parity = :none, stop_bits = 1)
    file_opts = RubySerial::Win32::GENERIC_READ | RubySerial::Win32::GENERIC_WRITE
    @fd = RubySerial::Win32.CreateFileA("\\\\.\\#{address}", file_opts, 0, nil, RubySerial::Win32::OPEN_EXISTING, 0,
                                        nil)
    err = FFI.errno
    raise RubySerial::Error, RubySerial::Win32::ERROR_CODES[err] if err != 0

    @open = true

    RubySerial::Win32::DCB.new.tap do |dcb|
      dcb[:dcblength] = RubySerial::Win32::DCB::Sizeof
      err = RubySerial::Win32.GetCommState @fd, dcb
      raise RubySerial::Error, RubySerial::Win32::ERROR_CODES[FFI.errno] if err.zero?

      dcb[:baudrate] = baude_rate
      dcb[:bytesize] = data_bits
      dcb[:stopbits] = RubySerial::Win32::DCB::STOPBITS[stop_bits]
      dcb[:parity]   = RubySerial::Win32::DCB::PARITY[parity]
      err = RubySerial::Win32.SetCommState @fd, dcb
      raise RubySerial::Error, RubySerial::Win32::ERROR_CODES[FFI.errno] if err.zero?
    end

    RubySerial::Win32::CommTimeouts.new.tap do |timeouts|
      timeouts[:read_interval_timeout]          = 10
      timeouts[:read_total_timeout_multiplier]  = 1
      timeouts[:read_total_timeout_constant]    = 10
      timeouts[:write_total_timeout_multiplier] = 1
      timeouts[:write_total_timeout_constant]   = 10
      err = RubySerial::Win32.SetCommTimeouts @fd, timeouts
      raise RubySerial::Error, RubySerial::Win32::ERROR_CODES[FFI.errno] if err.zero?
    end
  end

  def read(size)
    buff = FFI::MemoryPointer.new :char, size
    count = FFI::MemoryPointer.new :uint32, 1
    err = RubySerial::Win32.ReadFile(@fd, buff, size, count, nil)
    raise RubySerial::Error, RubySerial::Win32::ERROR_CODES[FFI.errno] if err.zero?

    buff.get_bytes(0, count.read_int)
  end

  def getbyte
    buff = FFI::MemoryPointer.new :char, 1
    count = FFI::MemoryPointer.new :uint32, 1
    err = RubySerial::Win32.ReadFile(@fd, buff, 1, count, nil)
    raise RubySerial::Error, RubySerial::Win32::ERROR_CODES[FFI.errno] if err.zero?

    if count.read_int.zero?
      nil
    else
      buff.get_bytes(0, 1).bytes.first
    end
  end

  def write(data)
    buff = FFI::MemoryPointer.from_string(data.to_s)
    count = FFI::MemoryPointer.new :uint32, 1
    err = RubySerial::Win32.WriteFile(@fd, buff, buff.size - 1, count, nil)
    raise RubySerial::Error, RubySerial::Win32::ERROR_CODES[FFI.errno] if err.zero?

    count.read_int
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
    Timeout.timeout(timeout) do
      gets(sep:, limit:)
    end
  end

  def close
    err = RubySerial::Win32.CloseHandle(@fd)
    raise RubySerial::Error, RubySerial::Win32::ERROR_CODES[FFI.errno] if err.zero?

    @open = false
  end

  def closed?
    !@open
  end

  private

  def get_until_sep(sep: nil, limit: nil)
    bytes = []
    loop do
      current_byte = getbyte
      bytes << current_byte unless current_byte.nil?

      # Calculate whether we've found the separator
      separator_size      = sep.bytes.size
      separator_reached   = (bytes.last(separator_size) == sep.bytes)

      # Check if we have a limit and it’s been reached
      limit_reached       = limit && (bytes.size == limit)

      # Stop reading if either condition is true
      break if separator_reached || limit_reached
    end

    bytes.map(&:chr).join
  end
end
