# frozen_string_literal: true

class RemoveNilCustomFieldsFromSolved < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      DELETE FROM post_custom_fields
      WHERE name = 'is_accepted_answer' AND value IS NULL
    SQL

    execute <<~SQL
      DELETE FROM topic_custom_fields
      WHERE name = 'accepted_answer_post_id' AND value IS NULL
    SQL

    execute <<~SQL
      DELETE FROM topic_custom_fields
      WHERE name = 'solved_auto_close_topic_timer_id' AND value IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
