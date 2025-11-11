# frozen_string_literal: true
class ResetIdentityOnAiSummary < ActiveRecord::Migration[7.0]
  def up
    add_index :ai_summaries, %i[target_type target_id]

    # we need to reset identity since we moved this from the old summary_sections table
    execute <<-SQL
      DO $$
      DECLARE
          max_id integer;
      BEGIN
          SELECT MAX(id) INTO max_id FROM ai_summaries;
          IF max_id IS NOT NULL THEN
              PERFORM setval(pg_get_serial_sequence('ai_summaries', 'id'), max_id);
          END IF;
      END $$
    SQL
  end

  def down
    remove_index :ai_summaries, %i[target_type target_id]
  end
end
