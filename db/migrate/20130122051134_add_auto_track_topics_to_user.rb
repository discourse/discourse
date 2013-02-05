class AddAutoTrackTopicsToUser < ActiveRecord::Migration
  def change
    add_column :users, :auto_track_topics, :boolean, null: false, default: false
  end
end
