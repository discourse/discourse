# frozen_string_literal: true

class AddSegmentToSidebarUrls < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_urls, :segment, :string, default: "primary", null: false
  end
end
