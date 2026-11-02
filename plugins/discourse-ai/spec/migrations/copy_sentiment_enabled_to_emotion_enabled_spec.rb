# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20261021061850_copy_sentiment_enabled_to_emotion_enabled.rb",
        )

RSpec.describe CopySentimentEnabledToEmotionEnabled do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    DB.exec(<<~SQL)
      DELETE FROM site_settings
      WHERE name IN ('ai_sentiment_enabled', 'ai_sentiment_emotion_enabled')
    SQL
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  %w[t f].each do |value|
    it "copies the stored #{value} value and datatype idempotently" do
      DB.exec(<<~SQL, value: value)
        INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
        VALUES ('ai_sentiment_enabled', :value, 5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL

      2.times { described_class.new.up }

      expect(DB.query_single(<<~SQL)).to eq([value, value])
          SELECT value FROM site_settings
          WHERE name IN ('ai_sentiment_enabled', 'ai_sentiment_emotion_enabled')
        SQL
      expect(DB.query_single(<<~SQL)).to eq([5])
          SELECT data_type FROM site_settings WHERE name = 'ai_sentiment_emotion_enabled'
        SQL
    end

    it "preserves an explicit new #{value} setting" do
      DB.exec(<<~SQL, value: value, old_value: value == "t" ? "f" : "t")
        INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
        VALUES ('ai_sentiment_enabled', :old_value, 5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
               ('ai_sentiment_emotion_enabled', :value, 5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL

      described_class.new.up

      expect(DB.query_single(<<~SQL)).to eq([value])
          SELECT value FROM site_settings WHERE name = 'ai_sentiment_emotion_enabled'
        SQL
    end
  end

  it "inserts nothing without a stored source setting" do
    described_class.new.up

    expect(DB.query_single(<<~SQL)).to be_empty
        SELECT name FROM site_settings
        WHERE name IN ('ai_sentiment_enabled', 'ai_sentiment_emotion_enabled')
      SQL
  end

  it "cannot be reversed" do
    expect { described_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
