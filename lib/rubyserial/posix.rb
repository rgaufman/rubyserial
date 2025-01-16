# frozen_string_literal: true

# Copyright (c) 2014-2016 The Hybrid Group

require 'English'
class Serial
  def initialize(address, baude_rate = 9600, data_bits = 8, parity = :none, stop_bits = 1)
    file_opts = RubySerial::Posix::O_RDWR | RubySerial::Posix::O_NOCTTY | RubySerial::Posix::O_NONBLOCK
    @fd = RubySerial::Posix.open(address, file_opts)

    raise RubySerial::Error, RubySerial::Posix::ERROR_CODES[FFI.errno] if @fd == -1

    @open = true

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

  def write(data)
    data = data.to_s
    n =  0
    while data.size > n
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
    Timeout.timeout(timeout) do
      gets(sep:, limit:)
    end
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
end
