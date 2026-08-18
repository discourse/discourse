# frozen_string_literal: true

module DiscourseAi
  module Inference
    class OpenAiEmbeddings
      def initialize(endpoint, api_key, model, dimensions)
        @endpoint = endpoint
        @api_key = api_key
        @model = model
        @dimensions = dimensions
      end

      attr_reader :endpoint, :api_key, :model, :dimensions

      def perform!(content)
        headers = { "Content-Type" => "application/json" }

        if endpoint.include?("azure")
          headers["api-key"] = api_key
        else
          headers["Authorization"] = "Bearer #{api_key}"
        end

        payload = { model: model, input: content }
        payload[:dimensions] = dimensions if dimensions.present?

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(endpoint, payload.to_json, headers)

        if response.status == 200
          JSON.parse(response.body, symbolize_names: true).dig(:data, 0, :embedding)
        else
          raise EmbeddingInferenceError.from_response(
                  provider: EmbeddingDefinition::OPEN_AI,
                  response: response,
                )
        end
      end
    end
  end
end
