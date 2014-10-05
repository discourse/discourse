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

