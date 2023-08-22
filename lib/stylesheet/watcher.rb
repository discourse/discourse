# frozen_string_literal: true

require "listen"

module Stylesheet
  class Watcher
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
          warn("[stylesheet watcher] Ignoring outside of rails root plugin: #{plugin.path.to_s}")
        end
      end
      @default_paths
    end

    def start
      Thread.new do
        begin
          worker_loop while true
        rescue => e
          STDERR.puts "CSS change notifier crashed \n#{e}"
          start
        end
      end

      listener_opts = { ignore: [/node_modules/], only: /\.s?css\z/ }
      listener_opts[:force_polling] = true if ENV["FORCE_POLLING"]

      Thread.new do
        begin
          plugins_paths =
            Dir
              .glob("#{Rails.root}/plugins/*")
              .map do |file|
                if File.symlink?(file)
                  File.expand_path(File.readlink(file), "#{Rails.root}/plugins")
                else
                  file
                end
              end
              .compact

          listener =
            Listen.to(*@paths, listener_opts) do |modified, added, _|
              paths = [modified, added].flatten
              paths.compact!
              paths.map! do |long|
                plugin_name = nil
                plugins_paths.each do |plugin_path|
                  if long.include?("#{plugin_path}/")
                    plugin_name = File.basename(plugin_path)
                    break
                  end
                end

                target = nil
                target_match =
                  long.match(/admin|desktop|mobile|publish|wizard|wcag|color_definitions/)
                target = target_match[0] if target_match&.length

                { basename: File.basename(long), target: target, plugin_name: plugin_name }
              end

              process_change(paths)
            end
        rescue => e
          STDERR.puts "Failed to listen for CSS changes: \n#{e}"
        end
        listener.start
        sleep
      end
    end

    def core_assets_refresh(target)
      if target&.match(/wcag|color_definitions/)
        Stylesheet::Manager.clear_color_scheme_cache!
        return
      end

      targets = target ? [target] : %w[desktop mobile admin]
      Stylesheet::Manager.clear_core_cache!(targets)
      message =
        targets.map! { |name| Stylesheet::Manager.new.stylesheet_data(name.to_sym) }.flatten!
      MessageBus.publish "/file-change", message
    end

    def plugin_assets_refresh(plugin_name, target)
      Stylesheet::Manager.clear_plugin_cache!(plugin_name)
      targets = []
      if target.present?
        if DiscoursePluginRegistry.stylesheets_exists?(plugin_name, target.to_sym)
          targets.push("#{plugin_name}_#{target.to_s}")
        end
      else
        targets.push(plugin_name)
      end
      message =
        targets.map! { |name| Stylesheet::Manager.new.stylesheet_data(name.to_sym) }.flatten!
      MessageBus.publish "/file-change", message
    end

    def worker_loop
      path = @queue.pop

      @queue.pop while @queue.length > 0

      if path[:plugin_name]
        plugin_assets_refresh(path[:plugin_name], path[:target])
      else
        core_assets_refresh(path[:target])
      end
    end

    def process_change(paths)
      paths.each { |path| @queue.push path }
    end
  end
end
