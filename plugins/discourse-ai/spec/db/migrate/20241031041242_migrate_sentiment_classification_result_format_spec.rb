# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/post_migrate/20241031041242_migrate_sentiment_classification_result_format",
        )

RSpec.describe MigrateSentimentClassificationResultFormat do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    enable_current_plugin
    connection.execute(<<~SQL)
      INSERT INTO classification_results (model_used, classification, created_at, updated_at) VALUES
        ('sentiment', '{"neutral": 65, "negative": 20, "positive": 14}', NOW(), NOW()),
        ('emotion', '{"sadness": 10, "surprise": 15, "fear": 5, "anger": 20, "joy": 30, "disgust": 8, "neutral": 10}', NOW(), NOW());
    SQL
  end

  after { connection.execute("DELETE FROM classification_results") }

  describe "#up" do
    before { described_class.new.up }

    it "migrates sentiment classifications correctly" do
      sentiment_result = connection.execute(<<~SQL).first
        SELECT * FROM classification_results
        WHERE model_used = 'cardiffnlp/twitter-roberta-base-sentiment-latest';
      SQL

      expected_sentiment = { "neutral" => 0.65, "negative" => 0.20, "positive" => 0.14 }

      expect(JSON.parse(sentiment_result["classification"])).to eq(expected_sentiment)
    end

    it "migrates emotion classifications correctly" do
      emotion_result = connection.execute(<<~SQL).first
        SELECT * FROM classification_results
        WHERE model_used = 'j-hartmann/emotion-english-distilroberta-base';
      SQL

      expected_emotion = {
        "sadness" => 0.10,
        "surprise" => 0.15,
        "fear" => 0.05,
        "anger" => 0.20,
        "joy" => 0.30,
        "disgust" => 0.08,
        "neutral" => 0.10,
      }

      expect(JSON.parse(emotion_result["classification"])).to eq(expected_emotion)
    end
  end
end
