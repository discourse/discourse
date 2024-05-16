# frozen_string_literal: true

class UpdateUserOptionsForThreadTitlePrompts < ActiveRecord::Migration[7.0]
  def up
    min, max = DB.query_single("SELECT MIN(user_id), MAX(user_id) FROM user_options")
    while min <= max
      DB.exec(
        "UPDATE user_options SET show_thread_title_prompts = true WHERE user_id >= #{min} AND user_id <= #{min + 100_000}",
      )
      min += 100_000
    end

    change_column_default :user_options, :show_thread_title_prompts, true
    change_column_null :user_options, :show_thread_title_prompts, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
