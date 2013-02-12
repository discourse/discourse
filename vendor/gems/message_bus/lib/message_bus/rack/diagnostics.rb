module MessageBus::Rack; end

class MessageBus::Rack::Diagnostics
  def initialize(app, config = {})
    @app = app
  end

  def index
    html = <<HTML
<!DOCTYPE html>
<html>
  <head></head>
  <body>
    <h2>Message Bus Diags</h2>
  </body>
</html>
HTML
    return [200, {"content-type" => "text/html;"}, html]
  end

  def call(env)

    return @app.call(env) unless env['PATH_INFO'].start_with? '/message-bus/_diagnostics'

    route = env['PATH_INFO'].split('/message_bus/_diagnostics')[1]
    
    if MessageBus.is_admin_lookup.nil? || !MessageBus.is_admin_lookup.call
      return [403, {}, ["not allowed"]]
    end

    return index unless route
    
    return [404, {}, ["not found"]]
  end
end
