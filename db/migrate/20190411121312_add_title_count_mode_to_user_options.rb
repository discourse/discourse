# frozen_string_literal: true

class AddTitleCountModeToUserOptions < ActiveRecord::Migration[5.2]
  def change
    add_column :user_options, :title_count_mode_key, :integer, null: false, default: 0
  end
end
