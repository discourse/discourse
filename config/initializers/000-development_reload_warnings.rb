# frozen_string_literal: true

# Development helper which prints a warning when you edit a non-autoloaded ruby file.
# These include initializers, middleware, plugin.rb files, and more.
# Launch the server with AUTO_RESTART=0 to disable automatic restarts.
if Rails.env.development? && !Rails.configuration.cache_classes && Discourse.running_in_rack?
  paths = [
    *Dir["#{Rails.root}/app/*"].reject { |path| path.end_with? "/assets" },
    "#{Rails.root}/config",
    "#{Rails.root}/lib",
    "#{Rails.root}/plugins"
  ]

  Listen.to(*paths, only: /\.rb$/) do |modified, added, removed|
    supervisor_pid = UNICORN_DEV_SUPERVISOR_PID
    auto_restart = supervisor_pid && ENV["AUTO_RESTART"] != "0"

    files = modified + added + removed

    not_autoloaded = files.filter_map do |file|
      autoloaded = Rails.autoloaders.main.autoloads.key? file
      Pathname.new(file).relative_path_from(Rails.root) if !autoloaded
    end

    if not_autoloaded.length > 0
      message = auto_restart ? "Restarting server..." : "Server restart required. Automate this by setting AUTO_RESTART=1."
      STDERR.puts "[DEV]: Edited files which are not autoloaded. #{message}"
      STDERR.puts not_autoloaded.map { |path| "- #{path}".indent(7) }.join("\n")
      Process.kill("USR2", supervisor_pid) if auto_restart
    end
  end.start
end
