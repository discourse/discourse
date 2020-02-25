# frozen_string_literal: true

require 'listen'

module Stylesheet
  class Watcher
    REDIS_KEY = "dev_last_used_theme_id"

    def self.theme_id=(v)
      Discourse.redis.set(REDIS_KEY, v)
    end

    def self.theme_id
      (Discourse.redis.get(REDIS_KEY) || SiteSetting.default_theme_id).to_i
    end

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
      Discourse.plugins.each do |p|
        @default_paths << File.dirname(p.path).sub(Rails.root.to_s, '').sub(/^\//, '')
      end
      @default_paths
    end

    def start

      Thread.new do
        begin
          while true
            worker_loop
          end
        rescue => e
          STDERR.puts "CSS change notifier crashed #{e}"
          start
        end
      end

      root = Rails.root.to_s

      listener_opts = { ignore: /xxxx/ }
      listener_opts[:force_polling] = true if ENV['FORCE_POLLING']

      @paths.each do |watch|
        Thread.new do
          begin
            plugins_paths = Dir.glob("#{Rails.root}/plugins/*").map do |file|
              File.symlink?(file) ? File.readlink(file) : file
            end.compact

            listener = Listen.to("#{root}/#{watch}", listener_opts) do |modified, added, _|
              paths = [modified, added].flatten
              paths.compact!
              paths.map! do |long|
                plugin_name = nil
                plugins_paths.each do |plugin_path|
                  if long.include?(plugin_path)
                    plugin_name = File.basename(plugin_path)
                    break
                  end
                end

                target = nil
                if !plugin_name
                  target_match = long.match(/admin|desktop|mobile/)
                  if target_match&.length
                    target = target_match[0]
                  end
                end

                {
                  basename: File.basename(long),
                  target: target,
                  plugin_name: plugin_name
                }
              end

              process_change(paths)
            end
          rescue => e
            STDERR.puts "Failed to listen for CSS changes at: #{watch}\n#{e}"
          end
          listener.start
          sleep
        end
      end
    end

    def core_assets_refresh(target)
      targets = target ? [target] : ["desktop", "mobile", "admin"]
      Stylesheet::Manager.clear_core_cache!(targets)
      message = targets.map! do |name|
        Stylesheet::Manager.stylesheet_data(name.to_sym, Stylesheet::Watcher.theme_id)
      end.flatten!
      MessageBus.publish '/file-change', message
    end

    def plugin_assets_refresh(plugin_name)
      Stylesheet::Manager.clear_plugin_cache!(plugin_name)
      targets = [plugin_name]
      targets.push("#{plugin_name}_mobile") if DiscoursePluginRegistry.stylesheets_exists?(plugin_name, :mobile)
      targets.push("#{plugin_name}_desktop") if DiscoursePluginRegistry.stylesheets_exists?(plugin_name, :desktop)

      message = targets.map! do |name|
        Stylesheet::Manager.stylesheet_data(name.to_sym, Stylesheet::Watcher.theme_id)
      end.flatten!
      MessageBus.publish '/file-change', message
    end

    def worker_loop
      path = @queue.pop

      while @queue.length > 0
        @queue.pop
      end

      if path[:plugin_name]
        plugin_assets_refresh(path[:plugin_name])
      else
        core_assets_refresh(path[:target])
      end
    end

    def process_change(paths)
      paths.each do |path|
        if path[:basename] =~ /\.(css|scss)$/
          @queue.push path
        end
      end
    end
  end
end
