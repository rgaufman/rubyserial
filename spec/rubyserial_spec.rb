# frozen_string_literal: true

require 'English'
require 'rubyserial'

describe 'rubyserial' do
  before do
    @ports = []
    if RubySerial::ON_WINDOWS
      # NOTE: Tests on windows require com0com
      # https://github.com/hybridgroup/rubyserial/raw/appveyor_deps/setup_com0com_W7_x64_signed.exe
      @ports[0] = '\\\\.\\CNCA0'
      @ports[1] = '\\\\.\\CNCB0'
    else
      File.delete('socat.log') if File.file?('socat.log')

      raise 'socat not found' unless `socat -h` && $CHILD_STATUS == 0

      Thread.new do
        system('socat -lf socat.log -d -d pty,raw,echo=0 pty,raw,echo=0')
      end

      @ptys = nil

      loop do
        next unless File.file? 'socat.log'

        @file = File.open('socat.log', 'r')
        @fileread = @file.read

        unless @fileread.count("\n") < 3
          @ptys = @fileread.scan(/PTY is (.*)/)
          break
        end
      end

      @ports = [@ptys[1][0], @ptys[0][0]]
    end

    @sp2 = Serial.new(@ports[0])
    @sp = Serial.new(@ports[1])
  end

  after do
    @sp2.close
    @sp.close
  end

  it 'should read and write' do
    @sp2.write('hello')
    # small delay so it can write to the other port.
    sleep 0.1
    check = @sp.read(5)
    expect(check).to eql('hello')
  end

  it 'should convert ints to strings' do
    expect(@sp2.write(123)).to eql(3)
    sleep 0.1
    expect(@sp.read(3)).to eql('123')
  end

  it 'write should return bytes written' do
    expect(@sp2.write('hello')).to eql(5)
  end

  it 'reading nothing should be blank' do
    expect(@sp.read(5)).to eql('')
  end

  it 'should give me nil on getbyte' do
    expect(@sp.getbyte).to be_nil
  end

  it 'should give me a zero byte from getbyte' do
    @sp2.write("\x00")
    sleep 0.1
    expect(@sp.getbyte).to eql(0)
  end

  it 'should give me bytes' do
    @sp2.write('hello')
    # small delay so it can write to the other port.
    sleep 0.1
    check = @sp.getbyte
    expect([check].pack('C')).to eql('h')
  end

  describe 'giving me lines' do
    it 'should give me a line' do
      @sp.write("no yes \n hello")
      sleep 0.1
      expect(@sp2.gets).to eql("no yes \n")
    end

    it 'should give me a line with block' do
      @sp.write("no yes \n hello")
      sleep 0.1
      result = ''
      @sp2.gets do |line|
        result = line
        break unless result.empty?
      end
      expect(result).to eql("no yes \n")
    end

    it 'should accept a sep param' do
      @sp.write('no yes END bleh')
      sleep 0.1
      expect(@sp2.gets(sep: 'END')).to eql('no yes END')
    end

    it 'should accept a limit param' do
      @sp.write("no yes \n hello")
      sleep 0.1
      expect(@sp2.gets(limit: 4)).to eql('no y')
    end

    it 'should accept limit and sep params' do
      @sp.write('no yes END hello')
      sleep 0.1
      expect(@sp2.gets(sep: 'END', limit: 20)).to eql('no yes END')
      @sp2.read(1000)
      @sp.write('no yes END hello')
      sleep 0.1
      expect(@sp2.gets(sep: 'END', limit: 4)).to eql('no y')
    end

    it 'should read a paragraph at a time' do
      @sp.write("Something \n Something else \n\n and other stuff")
      sleep 0.1
      expect(@sp2.gets(sep: "\n\n")).to eql("Something \n Something else \n\n")
    end
  end

  describe 'config' do
    it 'should accept EVEN parity' do
      @sp2.close
      @sp.close
      @sp2 = Serial.new(@ports[0], 19_200, 8, :even)
      @sp = Serial.new(@ports[1], 19_200, 8, :even)
      @sp.write("Hello!\n")
      expect(@sp2.gets).to eql("Hello!\n")
    end

    it 'should accept ODD parity' do
      @sp2.close
      @sp.close
      @sp2 = Serial.new(@ports[0], 19_200, 8, :odd)
      @sp = Serial.new(@ports[1], 19_200, 8, :odd)
      @sp.write("Hello!\n")
      expect(@sp2.gets).to eql("Hello!\n")
    end

    it 'should accept 1 stop bit' do
      @sp2.close
      @sp.close
      @sp2 = Serial.new(@ports[0], 19_200, 8, :none, 1)
      @sp = Serial.new(@ports[1], 19_200, 8, :none, 1)
      @sp.write("Hello!\n")
      expect(@sp2.gets).to eql("Hello!\n")
    end

    it 'should accept 2 stop bits' do
      @sp2.close
      @sp.close
      @sp2 = Serial.new(@ports[0], 19_200, 8, :none, 2)
      @sp = Serial.new(@ports[1], 19_200, 8, :none, 2)
      @sp.write("Hello!\n")
      expect(@sp2.gets).to eql("Hello!\n")
    end

    it 'should set baude rate, check #46 fixed' do
      skip 'Not a bug on Windows' if RubySerial::ON_WINDOWS
      @sp.close
      rate = 600
      @sp = Serial.new(@ports[1], rate)
      fd = @sp.instance_variable_get(:@fd)
      module RubySerial
        module Posix
          attach_function :tcgetattr, [:int, RubySerial::Posix::Termios], :int, blocking: true
        end
      end
      termios = RubySerial::Posix::Termios.new
      RubySerial::Posix.tcgetattr(fd, termios)
      expect(termios[:c_ispeed]).to eql(RubySerial::Posix::BAUDE_RATES[rate])
    end
  end

  describe 'readline_chunked optimization' do
    it 'should read with default newline terminator' do
      @sp2.write("hello world\n")
      sleep 0.1
      result = @sp.readline_chunked
      expect(result).to eql('hello world')
    end

    it 'should read with custom terminators' do
      @sp2.write('data/')
      sleep 0.1
      result = @sp.readline_chunked(terminators: ['/'])
      expect(result).to eql('data')  # Should strip the '/' terminator
    end

    it 'should detect ERROR responses' do
      @sp2.write('some data ERROR more data')
      sleep 0.1
      result = @sp.readline_chunked
      expect(result).to eql('some data ERROR more data')
    end

    it 'should detect OK responses' do
      @sp2.write('command result OK trailing')
      sleep 0.1
      result = @sp.readline_chunked
      expect(result).to eql('command result OK trailing')
    end

    it 'should handle multiple terminators' do
      @sp2.write("test data\n")
      sleep 0.1
      result = @sp.readline_chunked(terminators: ["\n", "/"])
      expect(result).to eql('test data')  # Should stop at newline and strip it
    end

    it 'should timeout appropriately' do
      start_time = Time.now
      result = @sp.readline_chunked(timeout: 1)
      duration = Time.now - start_time
      
      expect(result).to eql('')
      expect(duration).to be >= 1.0
      expect(duration).to be < 1.5  # Should not take much longer than timeout
    end

    it 'should handle chunked data arrival' do
      # Simulate data arriving in chunks
      Thread.new do
        sleep 0.05
        @sp2.write('chunk1')
        sleep 0.05
        @sp2.write('chunk2')
        sleep 0.05
        @sp2.write("\n")
      end
      
      result = @sp.readline_chunked(timeout: 2)
      expect(result).to eql('chunk1chunk2')
    end

    it 'should work with protocol-style terminators like Texecom' do
      @sp2.write("\\RESPONSE/")
      sleep 0.1
      result = @sp.readline_chunked(terminators: ["/"])
      expect(result).to eql("\\RESPONSE")
    end
  end
end
