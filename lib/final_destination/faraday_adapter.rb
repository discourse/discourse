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
  end
end
