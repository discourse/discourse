# frozen_string_literal: true

class SilenceLogger < Rails::Rack::Logger
  PATH_INFO = "PATH_INFO"
  HTTP_X_SILENCE_LOGGER = "HTTP_X_SILENCE_LOGGER"

  def initialize(app, opts = {})
    @app = app
    @opts = opts
    @opts[:silenced] ||= []

    # Rails introduces something called taggers in the Logger, needs to be initialized
    super(app)
  end

  def call(env)
    path_info = env[PATH_INFO]
    override = false

    if env[HTTP_X_SILENCE_LOGGER] || @opts[:silenced].include?(path_info) ||
         path_info.start_with?("/logs") || path_info.start_with?("/user_avatar") ||
         path_info.start_with?("/letter_avatar")
      if defined?(::Logster::Logger) && Logster.logger
        override = true
        Logster.logger.override_level = Logger::WARN
      end
      @app.call(env)
    else
      # TODO: Just call `super` instead when upgrading to Rails 7.2. With Rails
      # 7.1 there is a bug in `Rails::Rack::Logger` when there is more than one
      # `ActiveSupport::TaggedLogging` logger in the broadcast logger. It
      # results in duplicating the response from Rack as many times as there
      # are tagged loggers, returning an array of arrays.
      super.tap { break _1.first if _1.any?(Array) }
    end
  ensure
    Logster.logger.override_level = nil if override
  end
end

silenced = %w[
  /mini-profiler-resources/results
  /mini-profiler-resources/includes.js
  /mini-profiler-resources/includes.css
  /mini-profiler-resources/jquery.tmpl.js
]
Rails.configuration.middleware.swap Rails::Rack::Logger, SilenceLogger, silenced: silenced
