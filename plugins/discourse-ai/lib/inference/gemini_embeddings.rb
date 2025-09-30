# frozen_string_literal: true

module DiscourseAi
  module Inference
    class GeminiEmbeddings
      def initialize(embedding_url, api_key, dimensions = nil, referer = Discourse.base_url)
        @api_key = api_key
        @embedding_url = embedding_url
        @dimensions = dimensions
        @referer = referer
      end

      attr_reader :embedding_url, :api_key, :referer

      def perform!(content)
        headers = { "Referer" => referer, "Content-Type" => "application/json" }
        url = "#{embedding_url}\?key\=#{api_key}"
        body = { content: { parts: [{ text: content }] } }
        if !@dimensions.nil?
          body.merge!({ embedding_config: { output_dimensionality: @dimensions } })
        end

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(url, body.to_json, headers)

        case response.status
        when 200
          JSON.parse(response.body, symbolize_names: true).dig(:embedding, :values)
        else
          Rails.logger.warn(
            "Google Gemini Embeddings failed with status: #{response.status} body: #{response.body}",
          )
          raise Net::HTTPBadResponse.new(response.body.to_s)
        end
      end
    end
  end
end
