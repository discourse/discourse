module Middleware
  class OptionalSendfile < Rack::Sendfile
    def call(env)
      if env["_disable_accl"] == true
        @app.call(env)
      else
        super(env)
      end
    end
  end
end
