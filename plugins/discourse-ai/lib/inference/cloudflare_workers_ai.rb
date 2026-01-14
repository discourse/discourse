# frozen_string_literal: true

module DiscourseAi
  module Inference
    class CloudflareWorkersAi
      def initialize(endpoint, api_token, referer = Discourse.base_url)
        @endpoint = endpoint
        @api_token = api_token
        @referer = referer
      end

      attr_reader :endpoint, :api_token, :referer

      def perform!(content)
        headers = {
          "Referer" => Discourse.base_url,
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{api_token}",
        }

        payload = { text: [content] }

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(endpoint, payload.to_json, headers)

        case response.status
        when 200
          JSON.parse(response.body, symbolize_names: true).dig(:result, :data).first
        else
          Rails.logger.warn(
            "Cloudflare Workers AI Embeddings failed with status: #{response.status} body: #{response.body}",
          )
          raise Net::HTTPBadResponse.new(response.body.to_s)
        end
      end
    end
  end
end
