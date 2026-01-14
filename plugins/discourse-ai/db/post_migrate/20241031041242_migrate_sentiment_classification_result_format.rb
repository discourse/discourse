# frozen_string_literal: true
class MigrateSentimentClassificationResultFormat < ActiveRecord::Migration[7.1]
  def up
    DB.exec(<<~SQL)
      UPDATE classification_results
      SET
        model_used = 'cardiffnlp/twitter-roberta-base-sentiment-latest',
        classification = jsonb_build_object(
          'neutral', (classification->>'neutral')::float / 100,
          'negative', (classification->>'negative')::float / 100,
          'positive', (classification->>'positive')::float / 100
        )
      WHERE model_used = 'sentiment';

      UPDATE classification_results
      SET
        model_used = 'j-hartmann/emotion-english-distilroberta-base',
        classification = jsonb_build_object(
          'sadness', (classification->>'sadness')::float / 100,
          'surprise', (classification->>'surprise')::float / 100,
          'fear', (classification->>'fear')::float / 100,
          'anger', (classification->>'anger')::float / 100,
          'joy', (classification->>'joy')::float / 100,
          'disgust', (classification->>'disgust')::float / 100,
          'neutral', (classification->>'neutral')::float / 100
        )
      WHERE model_used = 'emotion';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
