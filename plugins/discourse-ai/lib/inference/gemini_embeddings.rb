# frozen_string_literal: true

module DiscourseAi
  module Inference
    class GeminiEmbeddings
      TASK_TYPES = {
        document: "RETRIEVAL_DOCUMENT",
        query: "RETRIEVAL_QUERY",
        clustering: "CLUSTERING",
        classification: "CLASSIFICATION",
      }.freeze

      def initialize(embedding_url, api_key, dimensions = nil, referer = Discourse.base_url)
        @api_key = api_key
        @embedding_url = embedding_url
        @dimensions = dimensions
        @referer = referer
      end

      attr_reader :embedding_url, :api_key, :referer

      def perform!(content, task: nil)
        headers = { "Referer" => referer, "Content-Type" => "application/json" }
        url = "#{embedding_url}\?key\=#{api_key}"
        body = { content: { parts: [{ text: content }] } }
        if task.present?
          body[:taskType] = TASK_TYPES.fetch(task.to_sym) do
            raise ArgumentError, "Unknown embedding task: #{task}"
          end
        end
        if !@dimensions.nil?
          body.merge!({ embedding_config: { output_dimensionality: @dimensions } })
        end

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(url, body.to_json, headers)

        if response.status == 200
          JSON.parse(response.body, symbolize_names: true).dig(:embedding, :values)
        else
          raise EmbeddingInferenceError.from_response(
                  provider: EmbeddingDefinition::GOOGLE,
                  response: response,
                )
        end
      end
    end
  end
end
