# frozen_string_literal: true

class FinalDestination
  class FaradayAdapter < Faraday::Adapter::NetHttp
    def net_http_connection(env)
      proxy = env[:request][:proxy]
      port = env[:url].port || (env[:url].scheme == "https" ? 443 : 80)
      if proxy
        FinalDestination::HTTP.new(
          env[:url].hostname,
          port,
          proxy[:uri].hostname,
          proxy[:uri].port,
          proxy[:user],
          proxy[:password],
        )
      else
        FinalDestination::HTTP.new(env[:url].hostname, port, nil)
      end
    end

    private

    def configure_ssl(http, ssl)
      if http.respond_to?(:allow_unverified_tls=)
        http.allow_unverified_tls =
          ssl_verify_mode(ssl) == OpenSSL::SSL::VERIFY_NONE || ssl[:verify_hostname] == false
      end
      super
    end
  end
end
