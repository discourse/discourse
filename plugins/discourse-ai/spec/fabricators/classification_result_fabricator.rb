# frozen_string_literal: true

Fabricator(:classification_result) do
  target { Fabricate(:post) }
  classification_type "sentiment"
end

Fabricator(:sentiment_classification, from: :classification_result) do
  model_used "cardiffnlp/twitter-roberta-base-sentiment-latest"
  classification { { negative: 0.72, neutral: 0.23, positive: 0.4 } }
end

Fabricator(:emotion_classification, from: :classification_result) do
  model_used "j-hartmann/emotion-english-distilroberta-base"
  classification do
    { sadness: 0.72, surprise: 0.23, fear: 0.4, anger: 0.87, joy: 0.22, disgust: 0.70 }
  end
end
