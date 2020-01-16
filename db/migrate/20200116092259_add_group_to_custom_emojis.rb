# frozen_string_literal: true

class AddGroupToCustomEmojis < ActiveRecord::Migration[6.0]
  def change
    add_column :custom_emojis, :group, :string, null: true, limit: 20
  end
end
