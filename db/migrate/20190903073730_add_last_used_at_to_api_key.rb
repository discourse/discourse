# frozen_string_literal: true
class AddLastUsedAtToApiKey < ActiveRecord::Migration[5.2]
  def change
    add_column :api_keys, :last_used_at, :datetime
  end
end
