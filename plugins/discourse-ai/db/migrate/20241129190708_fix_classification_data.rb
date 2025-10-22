# frozen_string_literal: true

class FixClassificationData < ActiveRecord::Migration[7.2]
  def up
    classifications = DB.query(<<~SQL)
      SELECT id, classification
      FROM classification_results
      WHERE classification_type = 'sentiment'
        AND SUBSTRING(LTRIM(classification::text), 1, 1) = '['
    SQL

    transformed =
      classifications.reduce([]) do |memo, c|
        hash_result = {}
        c.classification.each { |r| hash_result[r["label"]] = r["score"] }

        memo << { id: c.id, fixed_classification: hash_result }
      end

    transformed_json = transformed.to_json

    DB.exec(<<~SQL, values: transformed_json)
      UPDATE classification_results
      SET classification = N.fixed_classification
      FROM (
        SELECT (value::jsonb->'id')::integer AS id, (value::jsonb->'fixed_classification')::jsonb AS fixed_classification
        FROM jsonb_array_elements(:values::jsonb)
      ) N
      WHERE classification_results.id = N.id
        AND classification_type = 'sentiment'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
