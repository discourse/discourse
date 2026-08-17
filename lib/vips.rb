# frozen_string_literal: true

require "tmpdir"

class Vips
  DEFAULT_TIMEOUT = 30
  private_constant :DEFAULT_TIMEOUT

  RLIMITS = {
    cpu_seconds: 300,
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
      environment["VIPS_BLOCK_UNTRUSTED"] = "1" if !allow_untrusted

      Discourse::SafeExec.capture(
        *command,
        env: environment,
        unsetenv_others: true,
        read: [*Discourse::SafeExec.default_read_paths, "/etc/ld.so.cache", *read],
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
