# frozen_string_literal: true

module Middleware
  class CspScriptNonceInjector
    PLACEHOLDER_HEADER = "Discourse-CSP-Nonce-Placeholder"

    def initialize(app, settings = {})
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)

      if nonce_placeholder = headers.delete(PLACEHOLDER_HEADER)
        nonce = SecureRandom.alphanumeric(25)
        parts = []
        response.each { |part| parts << part.to_s.gsub(nonce_placeholder, nonce) }
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
