# frozen_string_literal: true
class AddLanguageToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_events, :language, :string, limit: 255
  end
end
