require 'listen'

module Stylesheet
  class Watcher

    def self.watch(paths=nil)
      watcher = new(paths)
      watcher.start
      watcher
    end

    def initialize(paths)
      @paths = paths || ["app/assets/stylesheets", "plugins"]
      @queue = Queue.new
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
      @paths.each do |watch|
        Thread.new do
          begin
            Listen.to("#{root}/#{watch}") do |modified, added, _|
              paths = [modified, added].flatten
              paths.compact!
              paths.map!{|long| long[(root.length+1)..-1]}
              process_change(paths)
            end
          rescue => e
            STDERR.puts "Failed to listen for CSS changes at: #{watch}\n#{e}"
          end
        end
      end
    end

    def worker_loop
      @queue.pop
      while @queue.length > 0
        @queue.pop
      end

      message = ["desktop", "mobile", "admin"].map do |name|
        {hash: SecureRandom.hex, name: "/stylesheets/#{name}.css"}
      end

      Stylesheet::Manager.cache.clear
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
