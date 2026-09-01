# frozen_string_literal: true

require "tmpdir"
require "image_processing/instrumentation"

# Runs ImageMagick under the Landlock sandbox (via Discourse::SafeExec) so a
# decoder bug parsing an untrusted upload is confined to an explicit filesystem
# allowlist with no network, not the full rights of the calling process.
module ImageMagick
  # memory_bytes sits above the policy.xml ceiling (memory 1GiB + map 2GiB) so a
  # legitimate ≤128MP decode is not killed; MALLOC_ARENA_MAX bounds per-thread
  # arenas that would otherwise inflate address space against it. cpu_seconds is
  # a runaway backstop above the wall-clock timeout.
  RLIMITS = {
    cpu_seconds: 300,
    memory_bytes: 4 * 1024 * 1024 * 1024,
    file_size_bytes: 10 * 1024 * 1024 * 1024,
    open_files: 1024,
  }.freeze

  DEFAULT_TIMEOUT = 30

  FONTCONFIG_READ_PATHS = %w[/etc/fonts /var/cache/fontconfig].freeze

  class << self
    def asset_read_paths
      @asset_read_paths ||=
        Discourse::SafeExec.existing_paths(
          [Rails.root.join("vendor").to_s, ENV["MAGICK_CONFIGURE_PATH"], *FONTCONFIG_READ_PATHS],
        )
    end

    def magick(*args, operation:, read: [], write: [], timeout: nil, nice: nil, failure_message: "")
      command = ["magick", *args]
      command = ["nice", "-n", nice.to_s, *command] if nice
      run(*command, operation:, read:, write:, timeout:, failure_message:)
    end

    def identify(*args, operation:, read: [], write: [], timeout: nil, failure_message: "")
      run("identify", *args, operation:, read:, write:, timeout:, failure_message:)
    end

    def run(*command, operation:, read:, write:, timeout:, failure_message:)
      # A private scratch dir keeps ImageMagick's disk-backed pixel cache inside
      # the write allowlist, so large images that spill to disk still succeed.
      Dir.mktmpdir("discourse-imagemagick-") do |scratch|
        ImageProcessing::Instrumentation.instrument(operation:) do
          Discourse::SafeExec.capture(
            *command,
            env: {
              **ENV.slice("PATH", "MAGICK_CONFIGURE_PATH", "LANG", "LC_ALL"),
              "MAGICK_TEMPORARY_PATH" => scratch,
              "TMPDIR" => scratch,
              "HOME" => scratch,
              "XDG_CACHE_HOME" => scratch,
              "MALLOC_ARENA_MAX" => "2",
            },
            unsetenv_others: true,
            read: [*Discourse::SafeExec.default_read_paths, *asset_read_paths, *read],
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
  end
  private_class_method :run
end
