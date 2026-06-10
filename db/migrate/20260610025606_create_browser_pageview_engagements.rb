# frozen_string_literal: true

class CreateBrowserPageviewEngagements < ActiveRecord::Migration[8.0]
  def change
    create_table :browser_pageview_engagements do |t|
      t.bigint :event_id, null: false
      t.datetime :created_at, null: false
    end

    add_index :browser_pageview_engagements, %i[event_id created_at]
  end
end
