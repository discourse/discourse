# frozen_string_literal: true

require "image_optim/cmd"
require "image_optim/path"
require "tmpdir"

# Route image_optim's optimizer binaries through the Landlock sandbox, confining
# them to the file being optimized with no network. Cmd.capture (version/CPU
# probes, no untrusted input) is intentionally not patched.
class ImageOptim
  ImageOptim::Path.prepend(DiscourseScratchDestination)
  # Per-thread tmp directory, so that we don't have to grant access to the global tmpdir
  class << self
    def discourse_tmp_root
      Thread.current[:discourse_image_optim_tmp_root] ||= Dir.mktmpdir("discourse-image-optim-")
    end
  end

  module DiscourseScratchDestination
    def temp_path(*args, &block)
      return super if args.any?

      super(ImageOptim.discourse_tmp_root, &block)
    end
  end

  module Cmd
    class << self
      def run(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        env = args.first.is_a?(Hash) ? args.shift : {}

        files = args.select { |arg| arg.is_a?(String) && File.file?(arg) }

        Discourse::SafeExec.capture(
          *args,
          env: {
            **env,
            "MALLOC_ARENA_MAX" => "2",
          },
          unsetenv_others: true,
          read: [*Discourse::SafeExec.default_read_paths, *files],
          write: [ImageOptim.discourse_tmp_root],
          execute: Discourse::SafeExec.default_execute_paths,
          timeout: options[:timeout]&.to_f || ImageMagick::DEFAULT_TIMEOUT,
          rlimits: ImageMagick::RLIMITS,
          seccomp_deny_network: true,
        )
        true
      rescue Discourse::Utils::CommandError
        # non-zero exit means "kept the original", like system(*args) => false
        false
      end
    end
  end
end
