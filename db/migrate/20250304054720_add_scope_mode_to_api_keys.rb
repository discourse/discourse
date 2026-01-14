# frozen_string_literal: true

class AddScopeModeToApiKeys < ActiveRecord::Migration[7.2]
  def change
    add_column :api_keys, :scope_mode, :integer, null: true
  end
end
