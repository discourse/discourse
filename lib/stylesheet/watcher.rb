# frozen_string_literal: true

require "listen"

module Stylesheet
  class Watcher
    CORE_TARGETS = %w[admin desktop mobile publish wizard wcag]
    SPECIAL_CORE_TARGETS = %w[color_definitions]

    def self.watch(paths = nil)
      watcher = new(paths)
      watcher.start
      watcher
    end

    def initialize(paths)
      @paths = paths || Watcher.default_paths
      @queue = Queue.new
    end

    def self.default_paths
      return @default_paths if @default_paths

      @default_paths = ["app/assets/stylesheets"]
      Discourse.plugins.each do |plugin|
        if plugin.path.to_s.include?(Rails.root.to_s)
          path = File.dirname(plugin.path).sub(Rails.root.to_s, "").sub(%r{\A/}, "")
          path << "/assets/stylesheets"
          @default_paths << path if File.exist?(path)
        else
          # if plugin doesn’t seem to be in our app, consider it as outside of the app
          # and ignore it
          warn("[stylesheet watcher] Ignoring outside of rails root plugin: #{plugin.path}")
        end
      end
      @default_paths
    end

    def start
      Thread.new do
        worker_loop while true
      rescue => e
        STDERR.puts "CSS change notifier crashed \n#{e}"
        start
      end

      listener_opts = { ignore: [/node_modules/], only: /\.s?css\z/ }
      listener_opts[:force_polling] = true if ENV["FORCE_POLLING"]

      Thread.new do
        begin
          plugins_paths =
            Dir
              .glob("#{Rails.root.join("plugins/*")}")
              .map do |file|
                if File.symlink?(file)
                  File.expand_path(File.readlink(file), "#{Rails.root.join("plugins")}")
                else
                  file
                end
              end
              .compact

          listener =
            Listen.to(*@paths, listener_opts) do |modified, added, _|
              paths = [modified, added].flatten.compact
              paths.map! { |path| path_data(path, plugins_paths) }

              process_change(paths)
            end
        rescue => e
          STDERR.puts "Failed to listen for CSS changes: \n#{e}"
        end
        listener.start
        sleep
      end
    end

    def path_data(path, plugins_paths)
      plugin_name = nil
      expanded_path = File.expand_path(path)

      plugins_paths.each do |plugin_path|
        next if !expanded_path.start_with?("#{plugin_path}/")

        plugin_name = File.basename(plugin_path)
        break
      end

      target = plugin_name ? nil : core_target(path)

      { basename: File.basename(path), target: target, plugin_name: plugin_name }
    end

    def core_target(path)
      relative_path =
        Pathname.new(File.expand_path(path)).relative_path_from(
          Rails.root.join("app/assets/stylesheets"),
        )
      path_parts = relative_path.each_filename.to_a
      target = path_parts[0...-1].find { |path_part| CORE_TARGETS.include?(path_part) }
      basename_target = File.basename(path_parts.last, ".scss")

      target ||
        if path_parts.one? && (CORE_TARGETS + SPECIAL_CORE_TARGETS).include?(basename_target)
          basename_target
        end
    rescue ArgumentError
      nil
    end

    def core_assets_refresh(target)
      if target&.match(/wcag|color_definitions/)
        Stylesheet::Manager.clear_color_scheme_cache!
        return
      end

      targets = target ? [target] : %w[admin common desktop mobile]
      Stylesheet::Manager.clear_core_cache!(targets)
      message =
        targets.map! { |name| Stylesheet::Manager.new.stylesheet_data(name.to_sym) }.flatten!
      MessageBus.publish "/file-change", message
    end

    def plugin_assets_refresh(plugin_name)
      Stylesheet::Manager.clear_plugin_cache!(plugin_name)

      # A changed file can't be mapped back to a single target (it may be a
      # shared partial), so refresh every target the plugin defines.
      targets = []
      targets << plugin_name if DiscoursePluginRegistry.stylesheets_exists?(plugin_name)
      DiscoursePluginRegistry::STYLESHEET_TARGETS.each do |target|
        if DiscoursePluginRegistry.stylesheets_exists?(plugin_name, target)
          targets << "#{plugin_name}_#{target}"
        end
      end

      message = targets.flat_map { |name| Stylesheet::Manager.new.stylesheet_data(name.to_sym) }
      MessageBus.publish "/file-change", message if message.present?
    end

    def worker_loop
      path = @queue.pop

      @queue.pop while @queue.length > 0

      if path[:plugin_name]
        plugin_assets_refresh(path[:plugin_name])
      else
        core_assets_refresh(path[:target])
      end
    end

    def process_change(paths)
      paths.each { |path| @queue.push path }
    end
  end
end
