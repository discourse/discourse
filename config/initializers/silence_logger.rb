class SilenceLogger < Rails::Rack::Logger
  def initialize(app, opts = {})
    @app = app
    @opts = opts
    @opts[:silenced] ||= []

    # Rails introduces something called taggers in the Logger, needs to be initialized
    super(app)
  end

  def call(env)
    prev_level = Rails.logger.level

    if env['HTTP_X_SILENCE_LOGGER'] || @opts[:silenced].include?(env['PATH_INFO'])
      Rails.logger.level = Logger::WARN
      result = @app.call(env)
      result
    else
      super(env)
    end
  ensure
    Rails.logger.level = prev_level
  end
end

silenced = ["/mini-profiler-resources/results", "/mini-profiler-resources/includes.js", "/mini-profiler-resources/includes.css", "/mini-profiler-resources/jquery.tmpl.js"]
Rails.configuration.middleware.swap Rails::Rack::Logger, SilenceLogger, :silenced => silenced
