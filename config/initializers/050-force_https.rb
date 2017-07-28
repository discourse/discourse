# tiny middleware to force https if needed
class Discourse::ForceHttpsMiddleware

  def initialize(app, config = {})
    @app = app
  end

  def call(env)
    env['rack.url_scheme'] = 'https' if SiteSetting.force_https
    @app.call(env)
  end

end
