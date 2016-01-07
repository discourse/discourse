# Just like Rack except we dont do a to_ary check so we can calculate length
# on body proxy objects
# Sets the Content-Length header on responses with fixed-length bodies.
class ContentLength
  TRANSFER_ENCODING = "Transfer-Encoding".freeze
  CONTENT_LENGTH = "Content-Length".freeze

  include Rack::Utils

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if !STATUS_WITH_NO_ENTITY_BODY.include?(status.to_i) &&
       !headers[CONTENT_LENGTH] &&
       !headers[TRANSFER_ENCODING]

      obody = body
      body, length = [], 0
      obody.each { |part| body << part; length += part.bytesize }

      body = Rack::BodyProxy.new(body) do
        obody.close if obody.respond_to?(:close)
      end

      headers[CONTENT_LENGTH] = length.to_s
    end

    [status, headers, body]
  end
end

# content length helps us instruct NGINX on how to deal with this
Rails.configuration.middleware.unshift ContentLength
