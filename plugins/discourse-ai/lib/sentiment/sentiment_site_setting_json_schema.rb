# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class SentimentSiteSettingJsonSchema
      def self.schema
        @schema ||= {
          type: "array",
          items: {
            type: "object",
            format: "table",
            title: "model",
            properties: {
              model_name: {
                type: "string",
              },
              endpoint: {
                type: "string",
              },
              api_key: {
                type: "string",
              },
            },
            required: %w[model_name endpoint api_key],
          },
        }
      end

      def self.values
        return {} if SiteSetting.ai_sentiment_model_configs.blank?
        JSON.parse(SiteSetting.ai_sentiment_model_configs, object_class: OpenStruct)
      end
    end
  end
end
