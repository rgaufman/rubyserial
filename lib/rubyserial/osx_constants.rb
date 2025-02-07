# frozen_string_literal: true

# Copyright (c) 2014-2016 The Hybrid Group

module RubySerial
  module Posix
    extend FFI::Library
    ffi_lib FFI::Library::LIBC

    O_RDWR = 0x0002
    O_NOCTTY = 0x20000
    O_NONBLOCK = 0x0004
    F_GETFL = 3
    F_SETFL = 4
    IGNPAR = 0x00000004
    PARENB = 0x00001000
    PARODD = 0x00002000
    VMIN = 16
    VTIME = 17
    CLOCAL = 0x00008000
    CSTOPB = 0x00000400
    CREAD  = 0x00000800
    CCTS_OFLOW = 0x00010000 # Clearing this disables RTS AND CTS.
    TCSANOW = 0
    NCCS = 20

    DATA_BITS = {
      5 => 0x00000000,
      6 => 0x00000100,
      7 => 0x00000200,
      8 => 0x00000300
    }.freeze

    BAUDE_RATES = {
      0 => 0,
      50 => 50,
      75 => 75,
      110 => 110,
      134 => 134,
      150 => 150,
      200 => 200,
      300 => 300,
      600 => 600,
      1200 => 1200,
      1800 => 1800,
      2400 => 2400,
      4800 => 4800,
      9600 => 9600,
      19_200 => 19_200,
      38_400 => 38_400,
      7200 =>  7200,
      14_400 => 14_400,
      28_800 => 28_800,
      57_600 => 57_600,
      76_800 => 76_800,
      115_200 => 115_200,
      230_400 => 230_400
    }.freeze

    PARITY = {
      none: 0x00000000,
      even: PARENB,
      odd: PARENB | PARODD
    }.freeze

    STOPBITS = {
      1 => 0x00000000,
      2 => CSTOPB
    }.freeze

    ERROR_CODES = {
      1 => 'EPERM',
      2 => 'ENOENT',
      3 => 'ESRCH',
      4 => 'EINTR',
      5 => 'EIO',
      6 => 'ENXIO',
      7 => 'E2BIG',
      8 => 'ENOEXEC',
      9 => 'EBADF',
      10 => 'ECHILD',
      11 => 'EDEADLK',
      12 => 'ENOMEM',
      13 => 'EACCES',
      14 => 'EFAULT',
      15 => 'ENOTBLK',
      16 => 'EBUSY',
      17 => 'EEXIST',
      18 => 'EXDEV',
      19 => 'ENODEV',
      20 => 'ENOTDIR',
      21 => 'EISDIR',
      22 => 'EINVAL',
      23 => 'ENFILE',
      24 => 'EMFILE',
      25 => 'ENOTTY',
      26 => 'ETXTBSY',
      27 => 'EFBIG',
      28 => 'ENOSPC',
      29 => 'ESPIPE',
      30 => 'EROFS',
      31 => 'EMLINK',
      32 => 'EPIPE',
      33 => 'EDOM',
      34 => 'ERANGE',
      35 => 'EAGAIN',
      36 => 'EINPROGRESS',
      37 => 'EALREADY',
      38 => 'ENOTSOCK',
      39 => 'EDESTADDRREQ',
      40 => 'EMSGSIZE',
      41 => 'EPROTOTYPE',
      42 => 'ENOPROTOOPT',
      43 => 'EPROTONOSUPPORT',
      44 => 'ESOCKTNOSUPPORT',
      45 => 'ENOTSUP',
      46 => 'EPFNOSUPPORT',
      47 => 'EAFNOSUPPORT',
      48 => 'EADDRINUSE',
      49 => 'EADDRNOTAVAIL',
      50 => 'ENETDOWN',
      51 => 'ENETUNREACH',
      52 => 'ENETRESET',
      53 => 'ECONNABORTED',
      54 => 'ECONNRESET',
      55 => 'ENOBUFS',
      56 => 'EISCONN',
      57 => 'ENOTCONN',
      58 => 'ESHUTDOWN',
      59 => 'ETOOMANYREFS',
      60 => 'ETIMEDOUT',
      61 => 'ECONNREFUSED',
      62 => 'ELOOP',
      63 => 'ENAMETOOLONG',
      64 => 'EHOSTDOWN',
      65 => 'EHOSTUNREACH',
      66 => 'ENOTEMPTY',
      67 => 'EPROCLIM',
      68 => 'EUSERS',
      69 => 'EDQUOT',
      70 => 'ESTALE',
      71 => 'EREMOTE',
      72 => 'EBADRPC',
      73 => 'ERPCMISMATCH',
      74 => 'EPROGUNAVAIL',
      75 => 'EPROGMISMATCH',
      76 => 'EPROCUNAVAIL',
      77 => 'ENOLCK',
      78 => 'ENOSYS',
      79 => 'EFTYPE',
      80 => 'EAUTH',
      81 => 'ENEEDAUTH',
      82 => 'EPWROFF',
      83 => 'EDEVERR',
      84 => 'EOVERFLOW',
      85 => 'EBADEXEC',
      86 => 'EBADARCH',
      87 => 'ESHLIBVERS',
      88 => 'EBADMACHO',
      89 => 'ECANCELED',
      90 => 'EIDRM',
      91 => 'ENOMSG',
      92 => 'EILSEQ',
      93 => 'ENOATTR',
      94 => 'EBADMSG',
      95 => 'EMULTIHOP',
      96 => 'ENODATA',
      97 => 'ENOLINK',
      98 => 'ENOSR',
      99 => 'ENOSTR',
      100 => 'EPROTO',
      101 => 'ETIME',
      102 => 'EOPNOTSUPP',
      103 => 'ENOPOLICY',
      104 => 'ENOTRECOVERABLE',
      105 => 'EOWNERDEAD',
      106 => 'ELAST'
    }.freeze

    class Termios < FFI::Struct
      layout  :c_iflag, :ulong,
              :c_oflag, :ulong,
              :c_cflag, :ulong,
              :c_lflag, :ulong,
              :c_line, :uchar,
              :cc_c, [:uchar, NCCS],
              :c_ispeed, :ulong,
              :c_ospeed, :ulong
    end

    attach_function :tcsetattr, [:int, :int, RubySerial::Posix::Termios], :int, blocking: true
    attach_function :fcntl, %i[int int varargs], :int, blocking: true
    attach_function :open, %i[pointer int], :int, blocking: true
    attach_function :close, [:int], :int, blocking: true
    attach_function :write, %i[int pointer int], :int, blocking: true
    attach_function :read, %i[int pointer int], :int, blocking: true
  end
end
