# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class SentimentSiteSettingJsonSchema
      class << self
        def schema
          @schema ||= {
            type: "array",
            items: {
              type: "object",
              format: "table",
              title: "model",
              properties: {
                classification_type: {
                  type: "string",
                  enum: %w[sentiment emotion],
                },
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
              required: %w[classification_type model_name endpoint api_key],
            },
          }
        end

        def values
          return {} if SiteSetting.ai_sentiment_model_configs.blank?
          JSON.parse(SiteSetting.ai_sentiment_model_configs, object_class: OpenStruct)
        end
      end
    end
  end
end
