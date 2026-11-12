# frozen_string_literal: true
class RebakeSharedAiConversationOneboxes < ActiveRecord::Migration[7.2]
  def up
    # Safe marking for rebake using raw SQL
    DB.exec(<<~SQL)
      UPDATE posts
      SET baked_version = NULL
      WHERE raw LIKE '%/discourse-ai/ai-bot/shared-ai-conversations/%';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
