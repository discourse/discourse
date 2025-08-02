# frozen_string_literal: true

class AddAutoTrackTopicsToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :auto_track_topics, :boolean, null: false, default: false
  end
end
