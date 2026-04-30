# frozen_string_literal: true

begin
  require "ffi" if RUBY_PLATFORM.include?("linux")
rescue LoadError
end

module Discourse
  module Seccomp
    class Error < StandardError
    end

    class UnsupportedError < Error
    end

    NETWORK_SYSCALLS = %w[
      socket
      socketpair
      connect
      bind
      listen
      accept
      accept4
      sendto
      sendmsg
      sendmmsg
      recvfrom
      recvmsg
      recvmmsg
    ].freeze

    def self.supported?
      return false if !RUBY_PLATFORM.include?("linux")
      return false if !defined?(::FFI)

      LibSeccomp.available?
    rescue Error
      false
    end

    def self.deny_network!
      raise UnsupportedError, "seccomp is unavailable" if !supported?

      LibC.set_no_new_privileges!
      LibSeccomp.deny_syscalls!(NETWORK_SYSCALLS)
    end

    if defined?(::FFI)
      module LibC
        extend FFI::Library

        ffi_lib FFI::Library::LIBC

        PR_SET_NO_NEW_PRIVS = 38

        attach_function :prctl, %i[int ulong ulong ulong ulong], :int

        def self.set_no_new_privileges!
          rc = prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0)
          raise Error, "prctl(PR_SET_NO_NEW_PRIVS) failed" if rc.negative?
        end
      end

      module LibSeccomp
        extend FFI::Library

        SCMP_ACT_ALLOW = 0x7fff0000
        SCMP_ACT_ERRNO = 0x00050000
        EPERM = 1

        begin
          ffi_lib "libseccomp.so.2"

          attach_function :seccomp_init, [:uint32], :pointer
          attach_function :seccomp_rule_add_array, %i[pointer uint32 int uint pointer], :int
          attach_function :seccomp_load, [:pointer], :int
          attach_function :seccomp_release, [:pointer], :void
          attach_function :seccomp_syscall_resolve_name, [:string], :int

          AVAILABLE = true
        rescue LoadError, FFI::NotFoundError
          AVAILABLE = false
        end

        def self.available?
          AVAILABLE
        end

        def self.deny_syscalls!(syscall_names)
          raise UnsupportedError, "seccomp is unavailable" if !available?

          context = seccomp_init(SCMP_ACT_ALLOW)
          raise Error, "seccomp_init failed" if context.null?

          begin
            syscall_names.each { |syscall_name| deny_syscall(context, syscall_name) }
            load_context(context)
          ensure
            seccomp_release(context)
          end
        end

        def self.deny_syscall(context, syscall_name)
          syscall_number = seccomp_syscall_resolve_name(syscall_name)
          return if syscall_number.negative?

          rc = seccomp_rule_add_array(context, errno_action(EPERM), syscall_number, 0, nil)
          raise Error, "seccomp_rule_add_array failed for #{syscall_name}" if rc.negative?
        end

        def self.load_context(context)
          rc = seccomp_load(context)
          raise Error, "seccomp_load failed" if rc.negative?
        end

        def self.errno_action(errno)
          SCMP_ACT_ERRNO | errno
        end
      end
    end
  end
end
