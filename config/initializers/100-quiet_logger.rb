# frozen_string_literal: true

Rails.application.config.assets.configure do |env|
  env.logger = Logger.new('/dev/null')
end

module DiscourseRackQuietAssetsLogger
  def call(env)
    override = false
    if (env['PATH_INFO'].index("/assets/") == 0) ||
       (env['PATH_INFO'].index("mini-profiler-resources") == 0)
      if ::Logster::Logger === Rails.logger
        override = true
        Rails.logger.override_level = Logger::ERROR
      end
    end

    super(env).tap do
      if override
        Rails.logger.override_level = nil
      end
    end
  end
end

Rails::Rack::Logger.prepend DiscourseRackQuietAssetsLogger
