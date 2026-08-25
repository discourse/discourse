# frozen_string_literal: true

require "mini_vips"
require "tmpdir"
require "image_processing/instrumentation"

# Runs mini_vips through Discourse::SafeExec so Landlock-supported systems
# confine decoder bugs to an explicit filesystem allowlist with no network,
# rather than the full rights of the calling process.
module DiscourseVips
  DEFAULT_TIMEOUT_SECONDS = 30
  private_constant :DEFAULT_TIMEOUT_SECONDS

  FONTCONFIG_READ_PATHS = %w[/etc/fonts /var/cache/fontconfig].freeze
  private_constant :FONTCONFIG_READ_PATHS

  # The dynamic linker reads this cache to locate libvips and the executable's
  # other shared libraries inside the filesystem sandbox.
  DYNAMIC_LINKER_CACHE_PATH = "/etc/ld.so.cache"
  private_constant :DYNAMIC_LINKER_CACHE_PATH

  # memory_bytes allows large image decodes; MALLOC_ARENA_MAX bounds per-thread
  # arenas that would otherwise inflate address space against it. cpu_seconds is
  # a runaway backstop above the wall-clock timeout.
  RLIMITS = {
    cpu_seconds: 300,
    memory_bytes: 4 * 1024 * 1024 * 1024,
    file_size_bytes: 10 * 1024 * 1024 * 1024,
    open_files: 1024,
  }.freeze
  private_constant :RLIMITS

  def self.asset_read_paths
    @asset_read_paths ||=
      Discourse::SafeExec.existing_paths(
        [DYNAMIC_LINKER_CACHE_PATH, bundled_font_path, *FONTCONFIG_READ_PATHS],
      )
  end

  def self.vips(*args, operation:, read: [], write: [], timeout: nil, nice: 10, failure_message: "")
    command = [executable, *args]
    command = ["nice", "-n", nice.to_s, *command] if nice
    run(*command, operation:, read:, write:, timeout:, failure_message:)
  end

  def self.run(*command, operation:, read:, write:, timeout:, failure_message:)
    # A private scratch dir keeps libvips temporary files inside the write
    # allowlist, so operations that spill to disk still succeed.
    Dir.mktmpdir("discourse-vips-helper-") do |scratch|
      ImageProcessing::Instrumentation.instrument(operation:) do
        Discourse::SafeExec.capture(
          *command,
          env: {
            **ENV.to_h.slice("PATH", "LANG", "LC_ALL"),
            "TMPDIR" => scratch,
            "HOME" => scratch,
            "XDG_CACHE_HOME" => scratch,
            "MALLOC_ARENA_MAX" => "2",
          },
          unsetenv_others: true,
          read: [*Discourse::SafeExec.default_read_paths, *asset_read_paths, *read],
          write: [scratch, *write],
          execute: [*Discourse::SafeExec.default_execute_paths, executable],
          timeout: timeout || DEFAULT_TIMEOUT_SECONDS,
          rlimits: RLIMITS,
          failure_message:,
          seccomp_deny_network: true,
        )
      end
    end
  end
  private_class_method :run

  def self.executable
    @executable ||= MiniVips.executable
  end
  private_class_method :executable

  def self.bundled_font_path
    File.join(File.dirname(File.dirname(executable)), "lib/mini_vips/fonts/NotoSans-Regular.ttf")
  end
  private_class_method :bundled_font_path
end
