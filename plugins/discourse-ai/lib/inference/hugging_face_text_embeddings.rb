# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class HuggingFaceTextEmbeddings
      def initialize(endpoint, key, referer = Discourse.base_url)
        @endpoint = endpoint
        @key = key
        @referer = referer
      end

      attr_reader :endpoint, :key, :referer

      class << self
        def reranker_configured?
          SiteSetting.ai_hugging_face_tei_reranker_endpoint.present? ||
            SiteSetting.ai_hugging_face_tei_reranker_endpoint_srv.present?
        end

        def rerank(content, candidates)
          headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }
          body = { query: content, texts: candidates, truncate: true }.to_json

          if SiteSetting.ai_hugging_face_tei_reranker_endpoint_srv.present?
            service =
              DiscourseAi::Utils::DnsSrv.lookup(
                SiteSetting.ai_hugging_face_tei_reranker_endpoint_srv,
              )
            api_endpoint = "https://#{service.target}:#{service.port}"
          else
            api_endpoint = SiteSetting.ai_hugging_face_tei_reranker_endpoint
          end

          if SiteSetting.ai_hugging_face_tei_reranker_api_key.present?
            headers["X-API-KEY"] = SiteSetting.ai_hugging_face_tei_reranker_api_key
            headers["Authorization"] = "Bearer #{SiteSetting.ai_hugging_face_tei_reranker_api_key}"
          end

          conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
          response = conn.post("#{api_endpoint}/rerank", body, headers)

          if response.status != 200
            raise Net::HTTPBadResponse.new("Status: #{response.status}\n\n#{response.body}")
          end

          JSON.parse(response.body, symbolize_names: true)
        end
      end

      def classify_by_sentiment!(content)
        response = do_request!(content)

        JSON.parse(response.body, symbolize_names: true)
      end

      def perform!(content)
        response = do_request!(content)

        JSON.parse(response.body, symbolize_names: true).first
      end

      private

      def do_request!(content)
        headers = { "Referer" => referer, "Content-Type" => "application/json" }
        body = { inputs: content, truncate: true }.to_json

        if key.present?
          headers["X-API-KEY"] = key
          headers["Authorization"] = "Bearer #{key}"
        end

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(endpoint, body, headers)

        raise Net::HTTPBadResponse.new(response.body.to_s) if ![200].include?(response.status)

        response
      end
    end
  end
end
