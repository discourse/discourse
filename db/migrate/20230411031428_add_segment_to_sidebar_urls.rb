# frozen_string_literal: true

class AddSegmentToSidebarUrls < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_urls, :segment, :integer, default: 0, null: false
  end
end
