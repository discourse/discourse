# frozen_string_literal: true

class UpdateUserOptionsForThreadTitlePrompts < ActiveRecord::Migration[7.0]
  def up
    change_column_default :user_options, :show_thread_title_prompts, true

    if DB.query_single(
         "SELECT 1 FROM user_options WHERE show_thread_title_prompts IS NULL LIMIT 1",
       ).first
      batch_size = 100_000
      min_id = DB.query_single("SELECT MIN(user_id) FROM user_options").first.to_i
      max_id = DB.query_single("SELECT MAX(user_id) FROM user_options").first.to_i
      while max_id >= min_id
        DB.exec(
          "UPDATE user_options SET show_thread_title_prompts = true WHERE user_id > #{max_id - batch_size} AND user_id <= #{max_id}",
        )
        max_id -= batch_size
      end
    end

    change_column_null :user_options, :show_thread_title_prompts, false
  end

  def down
  end
end
