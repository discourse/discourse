# https://github.com/redis/redis-rb/pull/591
class Redis
  class Client
    alias_method :old_initialize, :initialize

    def initialize(options = {})
      old_initialize(options)

      if options.include?(:connector) && options[:connector].is_a?(Class)
        @connector = options[:connector].new(@options)
      end
    end
  end
end

if Rails.env.development? && ENV['DISCOURSE_FLUSH_REDIS']
  puts "Flushing redis (development mode)"
  $redis.flushall
end

if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
        if forked
            Discourse.after_fork
        else
            # We're in conservative spawning mode. We don't need to do anything.
        end
    end
end

