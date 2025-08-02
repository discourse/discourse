# frozen_string_literal: true

class AddShowThreadTitlePromptsToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :show_thread_title_prompts, :boolean
  end
end
