# frozen_string_literal: true

class IncreaseSizeOfSidebarUrls < ActiveRecord::Migration[7.0]
  def up
    change_column :sidebar_urls, :value, :string, limit: 1000
  end

  def down
    change_column :sidebar_urls, :value, :string, limit: 200
  end
end
