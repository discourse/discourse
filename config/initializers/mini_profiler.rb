# If Mini Profiler is included via gem
if defined?(Rack::MiniProfiler)

  Rack::MiniProfiler.config.storage_instance = Rack::MiniProfiler::RedisStore.new(:connection =>  DiscourseRedis.new)

  # For our app, let's just show mini profiler always, polling is chatty so nuke that
  Rack::MiniProfiler.config.pre_authorize_cb = lambda do |env|
    (env['HTTP_USER_AGENT'] !~ /iPad|iPhone|Nexus 7/) &&
    (env['PATH_INFO'] !~ /^\/message-bus/) &&
    (env['PATH_INFO'] !~ /topics\/timings/) &&
    (env['PATH_INFO'] !~ /assets/) &&
    (env['PATH_INFO'] !~ /jasmine/) &&
    (env['PATH_INFO'] !~ /users\/.*\/avatar/) &&
    (env['PATH_INFO'] !~ /srv\/status/) &&
    (env['PATH_INFO'] !~ /commits-widget/)
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
      if Rack::MiniProfiler.current && name !~ /(process_action.action_controller)|(render_template.action_view)/
        @prf ||= {}
        @prf[id] ||= []
        @prf[id] << Rack::MiniProfiler.start_step("#{payload[:serializer] if name =~ /serialize.serializer/} #{name}")
      end
    end

    def finish(name,id,payload)
      if Rack::MiniProfiler.current && name !~ /(process_action.action_controller)|(render_template.action_view)/
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
