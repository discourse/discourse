# frozen_string_literal: true

logger Logger.new(STDOUT)

# tune down if not enough ram
worker_processes (ENV["UNICORN_WORKERS"] || 3).to_i

# stree-ignore
listen ENV["UNICORN_LISTENER"] || "#{(ENV["UNICORN_BIND_ALL"] ? "" : "127.0.0.1:")}#{(ENV["UNICORN_PORT"] || 3000).to_i}"

if ENV["RAILS_ENV"] == "production"
  # nuke workers after 30 seconds instead of 60 seconds (the default)
  timeout 27, cleanup: 3
else
  # we want a longer timeout in dev cause first request can be really slow
  timeout(ENV["UNICORN_TIMEOUT"] && ENV["UNICORN_TIMEOUT"].to_i || 60)
end

# Enable this flag to have unicorn test client connections by writing the
# beginning of the HTTP headers before calling the application.  This
# prevents calling the application for connections that have disconnected
# while queued.  This is only guaranteed to detect clients on the same
# host unicorn runs on, and unlikely to detect disconnects even on a
# fast LAN.
check_client_connection false

before_fork { |server| Discourse.redis.close }

initialized = false
after_mold_fork do |server, mold|
  unless initialized
    Discourse.preload_rails!

    initialized = true
  end
  Discourse.redis.close
  Discourse.before_fork
end

after_worker_fork do |server, worker|
  DiscourseEvent.trigger(:web_fork_started)
  Discourse.after_fork
  SignalTrapLogger.instance.after_fork
end
