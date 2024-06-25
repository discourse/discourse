# frozen_string_literal: true

Rails.application.config.assets.configure { |env| env.logger = Logger.new("/dev/null") }

module DiscourseRackQuietAssetsLogger
  def call(env)
    override = false
    if (env["PATH_INFO"].index("/assets/") == 0) || (env["PATH_INFO"].index("/stylesheets") == 0) ||
         (env["PATH_INFO"].index("/svg-sprite") == 0) ||
         (env["PATH_INFO"].index("/manifest") == 0) ||
         (env["PATH_INFO"].index("/service-worker") == 0) ||
         (env["PATH_INFO"].index("mini-profiler-resources") == 0) ||
         (env["PATH_INFO"].index("/srv/status") == 0)
      if defined?(::Logster::Logger) && Logster.logger
        override = true
        Logster.logger.override_level = Logger::ERROR
      end
    end

    super(env).tap { Logster.logger.override_level = nil if override }
  end
end

Rails::Rack::Logger.prepend DiscourseRackQuietAssetsLogger
