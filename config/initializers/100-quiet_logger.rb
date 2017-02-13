Rails.application.config.assets.configure do |env|
  env.logger = Logger.new('/dev/null')
end

Rails::Rack::Logger.class_eval do
  def call_with_quiet_assets(env)

    override = false
    if (env['PATH_INFO'].index("/assets/") == 0) or
       (env['PATH_INFO'].index("mini-profiler-resources") == 0)
      if ::Logster::Logger === Rails.logger
        override = true
        Rails.logger.override_level = Logger::ERROR
      end
    end

    call_without_quiet_assets(env).tap do
      if override
        Rails.logger.override_level = nil
      end
    end
  end
  alias_method_chain :call, :quiet_assets
end
