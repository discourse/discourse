Rails.application.config.assets.configure do |env|
  env.logger = Logger.new('/dev/null')
end

Rails::Rack::Logger.class_eval do
  def call_with_quiet_assets(env)
    previous_level = Rails.logger.level
    if (env['PATH_INFO'].index("/assets/") == 0) or
       (env['PATH_INFO'].index("mini-profiler-resources") == 0)
      Rails.logger.level = Logger::ERROR
    end

    call_without_quiet_assets(env).tap do
      Rails.logger.level = previous_level
    end
  end
  alias_method_chain :call, :quiet_assets
end
