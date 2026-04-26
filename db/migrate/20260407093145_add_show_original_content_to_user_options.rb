# frozen_string_literal: true

class AddShowOriginalContentToUserOptions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :show_original_content, :boolean, default: false, null: false
  end
end
