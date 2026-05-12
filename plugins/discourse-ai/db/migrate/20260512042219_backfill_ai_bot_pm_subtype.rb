# frozen_string_literal: true

class BackfillAiBotPmSubtype < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE topics
      SET subtype = 'ai_bot'
      FROM topic_custom_fields
      WHERE topic_custom_fields.topic_id = topics.id
        AND topics.archetype = 'private_message'
        AND topic_custom_fields.name = 'is_ai_bot_pm'
        AND topic_custom_fields.value = 't'
        AND topics.subtype IS DISTINCT FROM 'ai_bot'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
