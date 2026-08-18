# frozen_string_literal: true

require "tmpdir"

class Vips
  DEFAULT_TIMEOUT = 5
  private_constant :DEFAULT_TIMEOUT

  LIBVIPS_DYNAMIC_LINKER_CACHE_PATH = "/etc/ld.so.cache"
  private_constant :LIBVIPS_DYNAMIC_LINKER_CACHE_PATH

  FONTCONFIG_CONFIGURATION_PATH = "/etc/fonts"
  private_constant :FONTCONFIG_CONFIGURATION_PATH

  RLIMITS = {
    cpu_seconds: 5,
    memory_bytes: 4 * 1024 * 1024 * 1024,
    file_size_bytes: 10 * 1024 * 1024 * 1024,
    open_files: 1024,
  }.freeze
  private_constant :RLIMITS

  def self.run(
    *command,
    read: [],
    write: [],
    timeout: nil,
    nice: nil,
    allow_untrusted: false,
    failure_message: ""
  )
    if !Rails.env.local? && !Discourse::SafeExec.landlock_supported?
      raise Discourse::Utils::CommandError,
            "Cannot run libvips because Landlock sandboxing is unavailable"
    end

    command = ["nice", "-n", nice.to_s, *command] if nice
    Dir.mktmpdir("discourse-vips-") do |scratch|
      environment = {
        **ENV.slice("PATH", "LANG", "LC_ALL"),
        "TMPDIR" => scratch,
        "HOME" => scratch,
        "XDG_CACHE_HOME" => scratch,
        "MALLOC_ARENA_MAX" => "2",
      }
      # libvips permits operations marked untrusted by default. Block them unless explicitly allowed.
      # See https://github.com/libvips/libvips/blob/v8.18.2/doc/developer-checklist.md#L101-L104
      # Future enhancement: define explicit operation block and allow lists through the CLI.
      # See https://github.com/libvips/libvips/issues/5174
      environment["VIPS_BLOCK_UNTRUSTED"] = "1" if !allow_untrusted

      Discourse::SafeExec.capture(
        *command,
        env: environment,
        unsetenv_others: true,
        read: [
          *Discourse::SafeExec.default_read_paths,
          LIBVIPS_DYNAMIC_LINKER_CACHE_PATH,
          FONTCONFIG_CONFIGURATION_PATH,
          *read,
        ],
        write: [scratch, *write],
        execute: Discourse::SafeExec.default_execute_paths,
        timeout: timeout || DEFAULT_TIMEOUT,
        rlimits: RLIMITS,
        failure_message:,
        seccomp_deny_network: true,
      )
    end
  end
end
