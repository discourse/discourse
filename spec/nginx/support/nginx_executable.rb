# frozen_string_literal: true

module Nginx
  module Support
    # Resolves the nginx executable the suite will actually run, the same
    # way Process.spawn("nginx") / execvp does: first match for a file
    # named "nginx" that is executable, walking ENV["PATH"] in order.
    #
    # The availability probe and the spawn must agree on the same binary,
    # so both go through here rather than the probe shelling out to
    # `which` (which can resolve differently, or be missing entirely on a
    # minimal system, giving a false "not available").
    module NginxExecutable
      module_function

      def path
        # An explicit override wins, mirroring how an operator would point
        # the suite at a specific build.
        if (override = ENV["NGINX_BIN"]) && !override.empty?
          return File.executable?(override) ? override : nil
        end

        ENV["PATH"]
          .to_s
          .split(File::PATH_SEPARATOR)
          .each do |dir|
            next if dir.empty?

            candidate = File.join(dir, "nginx")
            return candidate if File.file?(candidate) && File.executable?(candidate)
          end

        nil
      end

      def available?
        !path.nil?
      end
    end
  end
end
