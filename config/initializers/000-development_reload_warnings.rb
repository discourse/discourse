# frozen_string_literal: true

# Development helper which prints a warning when you edit a non-autoloaded ruby file.
# These include initializers, middleware, plugin.rb files, and more.
# Launch the server with AUTO_RESTART=0 to disable automatic restarts.
if Rails.env.development? && !Rails.configuration.cache_classes && Discourse.running_in_rack?
  paths = [
    *Dir["#{Rails.root}/app/*"].reject { |path| path.end_with? "/assets" },
    "#{Rails.root}/config",
    "#{Rails.root}/lib",
    "#{Rails.root}/plugins",
  ]

  if Listen::Adapter::Linux.usable?
    # The Listen gem watches recursively, which has a cost per-file on Linux (via rb-inotify)
    # Skip a bunch of unnecessary directories to reduce the cost
    # Ref https://github.com/guard/listen/issues/556
    require "rb-inotify"
    INotify::Notifier.prepend(
      Module.new do
        def watch(path, *flags, &callback)
          return if path.end_with?("/node_modules", "/.git")
          super(path, *flags, &callback)
        end
      end,
    )
  end

  Listen
    .to(*paths, only: /\.rb$/, ignore: [/node_modules/]) do |modified, added, removed|
      supervisor_pid = UNICORN_DEV_SUPERVISOR_PID
      auto_restart = supervisor_pid && ENV["AUTO_RESTART"] != "0"

      files = modified + added + removed

      not_autoloaded =
        files.filter_map do |file|
          autoloaded = Rails.autoloaders.main.__autoloads.key? file

          if !autoloaded && !file.match(%r{/spec/})
            Pathname.new(file).relative_path_from(Rails.root)
          end
        end

      if not_autoloaded.length > 0
        message =
          (
            if auto_restart
              "Restarting server..."
            else
              "Server restart required. Automate this by setting AUTO_RESTART=1."
            end
          )
        STDERR.puts "[DEV]: Edited files which are not autoloaded. #{message}"
        STDERR.puts not_autoloaded.map { |path| "- #{path}".indent(7) }.join("\n")
        Process.kill("USR2", supervisor_pid) if auto_restart
      end
    end
    .start
end
