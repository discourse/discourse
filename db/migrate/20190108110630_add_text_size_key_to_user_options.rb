# frozen_string_literal: true

class AddTextSizeKeyToUserOptions < ActiveRecord::Migration[5.2]
  def change
    add_column :user_options, :text_size_key, :integer, null: false, default: 0
  end
end
