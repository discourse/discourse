# frozen_string_literal: true

class SetAiBotPmCustomFields < ActiveRecord::Migration[7.2]
  def up
    # Set the topic custom field for past bot PMs:
    # - Created by a "real" user (user_id > 0)
    # - Include exactly 2 participants (creator and 1 bot)
    # - One participant is a bot (ID <= -1200)

    execute <<~SQL
      INSERT INTO topic_custom_fields (topic_id, name, value, created_at, updated_at)
      SELECT t.id, 'is_ai_bot_pm', 't', NOW(), NOW()
      FROM topics t
      WHERE t.archetype = 'private_message'
      AND t.user_id > 0 -- Created by a real user
      AND (
        SELECT COUNT(*)
        FROM topic_allowed_users tau
        WHERE tau.topic_id = t.id
      ) = 2 -- Only 2 participants total
      AND (
        SELECT COUNT(*)
        FROM topic_allowed_users tau
        WHERE tau.topic_id = t.id
        AND tau.user_id <= -1200 -- Bot users have IDs <= -1200
      ) = 1 -- One of those participants is a bot
      AND NOT EXISTS (
        SELECT 1
        FROM topic_custom_fields tcf
        WHERE tcf.topic_id = t.id
        AND tcf.name = 'is_ai_bot_pm'
      ) -- Don't duplicate existing custom fields
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
