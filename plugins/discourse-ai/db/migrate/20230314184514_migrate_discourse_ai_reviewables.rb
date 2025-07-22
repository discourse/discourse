# frozen_string_literal: true
class MigrateDiscourseAiReviewables < ActiveRecord::Migration[7.0]
  def up
    DB.exec("UPDATE reviewables SET type='ReviewableAiPost' WHERE type='ReviewableAIPost'")
    DB.exec(
      "UPDATE reviewables SET type='ReviewableAiChatMessage' WHERE type='ReviewableAIChatMessage'",
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
