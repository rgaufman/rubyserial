# frozen_string_literal: true

# Copyright (c) 2014-2016 The Hybrid Group

module RubySerial
  module Posix
    extend FFI::Library
    ffi_lib FFI::Library::LIBC

    O_NONBLOCK = 0o0004000
    O_NOCTTY = 0o0000400
    O_RDWR = 0o0000002
    F_GETFL = 3
    F_SETFL = 4
    VTIME = 5
    TCSANOW = 0
    TCSETS = 0x5402
    IGNPAR = 0o000004
    PARENB = 0o000400
    PARODD = 0o001000
    CSTOPB = 0o000100
    CREAD  = 0o000200
    CLOCAL = 0o004000
    VMIN = 6
    NCCS = 32

    DATA_BITS = {
      5 => 0o000000,
      6 => 0o000020,
      7 => 0o000040,
      8 => 0o000060
    }.freeze

    BAUDE_RATES = {
      0 => 0o000000,
      50 => 0o000001,
      75 => 0o000002,
      110 => 0o000003,
      134 => 0o000004,
      150 => 0o000005,
      200 => 0o000006,
      300 => 0o000007,
      600 => 0o000010,
      1200 => 0o000011,
      1800 => 0o000012,
      2400 => 0o000013,
      4800 => 0o000014,
      9600 => 0o000015,
      19_200 => 0o000016,
      38_400 => 0o000017,
      57_600 => 0o010001,
      115_200 => 0o010002,
      230_400 => 0o010003,
      460_800 => 0o010004,
      500_000 => 0o010005,
      576_000 => 0o010006,
      921_600 => 0o010007,
      1_000_000 => 0o010010,
      1_152_000 => 0o010011,
      1_500_000 => 0o010012,
      2_000_000 => 0o010013,
      2_500_000 => 0o010014,
      3_000_000 => 0o010015,
      3_500_000 => 0o010016,
      4_000_000 => 0o010017
    }.freeze

    PARITY = {
      none: 0o000000,
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
      11 => 'EAGAIN',
      12 => 'ENOMEM',
      13 => 'EACCES',
      14 => 'EFAULT',
      15 => 'ENOTBLK',
      16 => 'EBUSY',
      17 => 'EEXIST',
      18 => 'EXDEV',
      19 => 'ENODEV',
      20 => 'ENOTDIR ',
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
      35 => 'EDEADLK',
      36 => 'ENAMETOOLONG',
      37 => 'ENOLCK ',
      38 => 'ENOSYS',
      39 => 'ENOTEMPTY',
      40 => 'ELOOP',
      42 => 'ENOMSG',
      43 => 'EIDRM',
      44 => 'ECHRNG',
      45 => 'EL2NSYNC',
      46 => 'EL3HLT',
      47 => 'EL3RST',
      48 => 'ELNRNG',
      49 => 'EUNATCH',
      50 => 'ENOCSI',
      51 => 'EL2HLT',
      52 => 'EBADE',
      53 => 'EBADR',
      54 => 'EXFULL',
      55 => 'ENOANO',
      56 => 'EBADRQC',
      57 => 'EBADSLT',
      59 => 'EBFONT',
      60 => 'ENOSTR',
      61 => 'ENODATA',
      62 => 'ETIME',
      63 => 'ENOSR',
      64 => 'ENONET',
      65 => 'ENOPKG',
      66 => 'EREMOTE',
      67 => 'ENOLINK',
      68 => 'EADV',
      69 => 'ESRMNT',
      70 => 'ECOMM',
      71 => 'EPROTO',
      72 => 'EMULTIHOP',
      73 => 'EDOTDOT',
      74 => 'EBADMSG',
      75 => 'EOVERFLOW',
      76 => 'ENOTUNIQ',
      77 => 'EBADFD',
      78 => 'EREMCHG',
      79 => 'ELIBACC',
      80 => 'ELIBBAD',
      81 => 'ELIBSCN',
      82 => 'ELIBMAX',
      83 => 'ELIBEXEC',
      84 => 'EILSEQ',
      85 => 'ERESTART',
      86 => 'ESTRPIPE',
      87 => 'EUSERS',
      88 => 'ENOTSOCK',
      89 => 'EDESTADDRREQ',
      90 => 'EMSGSIZE',
      91 => 'EPROTOTYPE',
      92 => 'ENOPROTOOPT',
      93 => 'EPROTONOSUPPORT',
      94 => 'ESOCKTNOSUPPORT',
      95 => 'EOPNOTSUPP',
      96 => 'EPFNOSUPPORT',
      97 => 'EAFNOSUPPORT',
      98 => 'EADDRINUSE',
      99 => 'EADDRNOTAVAIL',
      100 => 'ENETDOWN',
      101 => 'ENETUNREACH',
      102 => 'ENETRESET',
      103 => 'ECONNABORTED',
      104 => 'ECONNRESET',
      105 => 'ENOBUFS',
      106 => 'EISCONN',
      107 => 'ENOTCONN',
      108 => 'ESHUTDOWN',
      109 => 'ETOOMANYREFS',
      110 => 'ETIMEDOUT',
      111 => 'ECONNREFUSED',
      112 => 'EHOSTDOWN',
      113 => 'EHOSTUNREACH',
      114 => 'EALREADY',
      115 => 'EINPROGRESS',
      116 => 'ESTALE',
      117 => 'EUCLEAN',
      118 => 'ENOTNAM',
      119 => 'ENAVAIL',
      120 => 'EISNAM',
      121 => 'EREMOTEIO',
      122 => 'EDQUOT',
      123 => 'ENOMEDIUM',
      124 => 'EMEDIUMTYPE',
      125 => 'ECANCELED',
      126 => 'ENOKEY',
      127 => 'EKEYEXPIRED',
      128 => 'EKEYREVOKED',
      129 => 'EKEYREJECTED',
      130 => 'EOWNERDEAD',
      131 => 'ENOTRECOVERABLE'
    }.freeze

    class Termios < FFI::Struct
      layout  :c_iflag, :uint,
              :c_oflag, :uint,
              :c_cflag, :uint,
              :c_lflag, :uint,
              :c_line, :uchar,
              :cc_c, [:uchar, NCCS],
              :c_ispeed, :uint,
              :c_ospeed, :uint
    end

    attach_function :ioctl, [:int, :ulong, RubySerial::Posix::Termios], :int, blocking: true
    attach_function :tcsetattr, [:int, :int, RubySerial::Posix::Termios], :int, blocking: true
    attach_function :fcntl, %i[int int varargs], :int, blocking: true
    attach_function :open, %i[pointer int], :int, blocking: true
    attach_function :close, [:int], :int, blocking: true
    attach_function :write, %i[int pointer int], :int, blocking: true
    attach_function :read, %i[int pointer int], :int, blocking: true
  end
end
