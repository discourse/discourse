# frozen_string_literal: true

module Middleware
  class GtmScriptNonceInjector
    def initialize(app, settings = {})
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)

      if nonce_placeholder = headers.delete("Discourse-GTM-Nonce-Placeholder")
        nonce = SecureRandom.hex
        parts = []
        response.each { |part| parts << part.to_s.sub(nonce_placeholder, nonce) }
        %w[Content-Security-Policy Content-Security-Policy-Report-Only].each do |name|
          next if headers[name].blank?
          headers[name] = headers[name].sub("script-src ", "script-src 'nonce-#{nonce}' ")
        end
        [status, headers, parts]
      else
        [status, headers, response]
      end
    end
  end
end
