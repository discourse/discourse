# If Mini Profiler is included via gem
if defined?(Rack::MiniProfiler)

  Rack::MiniProfiler.config.storage_options = YAML::load(File.open("#{Rails.root}/config/redis.yml"))[Rails.env].symbolize_keys
  Rack::MiniProfiler.config.storage = Rack::MiniProfiler::RedisStore

  # For our app, let's just show mini profiler always, polling is chatty so nuke that
  Rack::MiniProfiler.config.pre_authorize_cb = lambda do |env|
    (env['HTTP_USER_AGENT'] !~ /iPad|iPhone|Nexus 7/) and
    (env['PATH_INFO'] !~ /^\/message-bus/) and
    (env['PATH_INFO'] !~ /topics\/timings/) and
    (env['PATH_INFO'] !~ /assets/) and
    (env['PATH_INFO'] !~ /jasmine/) and
    (env['PATH_INFO'] !~ /users\/.*\/avatar/) and
    (env['PATH_INFO'] !~ /srv\/status/)
  end

  Rack::MiniProfiler.config.position = 'left'
  Rack::MiniProfiler.config.backtrace_ignores ||= []
  Rack::MiniProfiler.config.backtrace_ignores << /lib\/rack\/message_bus.rb/
  Rack::MiniProfiler.config.backtrace_ignores << /config\/initializers\/silence_logger/
  Rack::MiniProfiler.config.backtrace_ignores << /config\/initializers\/quiet_logger/
  #Rack::MiniProfiler.config.style = :awesome_bar

  # require "#{Rails.root}/vendor/backports/notification"

  inst = Class.new
  class << inst
    def start(name,id,payload)
      if Rack::MiniProfiler.current and  name !~ /(process_action.action_controller)|(render_template.action_view)/
        @prf ||= {}
        @prf[id] ||= []
        @prf[id] << Rack::MiniProfiler.start_step("#{payload[:serializer] if name =~ /serialize.serializer/} #{name}")
      end
    end

    def finish(name,id,payload)
      if Rack::MiniProfiler.current and  name !~ /(process_action.action_controller)|(render_template.action_view)/
        t = @prf[id].pop
        @prf.delete id unless t
        Rack::MiniProfiler.finish_step t
      end
    end
  end
  # disabling for now cause this slows stuff down too much
  # ActiveSupport::Notifications.subscribe(/.*/, inst)

  # Rack::MiniProfiler.profile_method ActionView::PathResolver, 'find_templates'
end
