# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    module Constants
      SENTIMENT_MODEL = "cardiffnlp/twitter-roberta-base-sentiment-latest"
      EMOTION_MODEL = "SamLowe/roberta-base-go_emotions"
      SENTIMENT_AGENT_MODEL = "discourse-ai/sentiment-agent"
      EMOTION_AGENT_MODEL = "discourse-ai/emotion-agent"
      CLASSIFICATION_MODEL_STRATEGY = "classification_model"
      AGENT_STRATEGY = "agent"
      SENTIMENT_THRESHOLD = 0.6
    end
  end
end
