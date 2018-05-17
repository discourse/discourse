require 'listen'

module Stylesheet
  class Watcher

    def self.theme_key=(v)
      @theme_key = v
    end

    def self.theme_key
      @theme_key || SiteSetting.default_theme_key
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
        end
      end

      root = Rails.root.to_s

      listener_opts = { ignore: /xxxx/ }
      listener_opts[:force_polling] = true if ENV['FORCE_POLLING']

      @paths.each do |watch|
        Thread.new do
          begin
            listener = Listen.to("#{root}/#{watch}", listener_opts) do |modified, added, _|
              paths = [modified, added].flatten
              paths.compact!
              paths.map! { |long| long[(root.length + 1)..-1] }
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

    def worker_loop
      @queue.pop
      while @queue.length > 0
        @queue.pop
      end

      Stylesheet::Manager.cache.clear

      message = ["desktop", "mobile", "admin"].map do |name|
        {
          target: name,
          new_href: Stylesheet::Manager.stylesheet_href(name.to_sym),
          theme_key: Stylesheet::Watcher.theme_key
        }
      end
      MessageBus.publish '/file-change', message
    end

    def process_change(paths)
      paths.each do |path|
        if path =~ /\.(css|scss)$/
          @queue.push path
        end
      end
    end

  end
end
