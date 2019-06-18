# frozen_string_literal: true

class AddExernalUrlToPermalinks < ActiveRecord::Migration[4.2]
  def change
    add_column :permalinks, :external_url, :string, limit: 1000
  end
end
