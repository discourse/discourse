# frozen_string_literal: true

require "image_optim/cmd"

# Route image_optim's optimizer binaries through the Landlock sandbox, confining
# them to the file being optimized with no network. Cmd.capture (version/CPU
# probes, no untrusted input) is intentionally not patched.
class ImageOptim
  module Cmd
    class << self
      def run(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        env = args.first.is_a?(Hash) ? args.shift : {}

        files = args.select { |arg| arg.is_a?(String) && File.file?(arg) }
        dirs = files.map { |file| File.dirname(file) }.uniq

        Discourse::SafeExec.capture(
          *args,
          env: {
            **env,
            "MALLOC_ARENA_MAX" => "2",
          },
          unsetenv_others: true,
          read: [*Discourse::SafeExec.default_read_paths, *files],
          write: [*files, *dirs],
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
