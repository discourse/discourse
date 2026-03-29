# frozen_string_literal: true
class AddImageUploadIdToEvents < ActiveRecord::Migration[8.0]
  def up
    add_column :discourse_post_event_events, :image_upload_id, :bigint
    add_index :discourse_post_event_events, :image_upload_id
  end

  def down
    remove_column :discourse_post_event_events, :image_upload_id
  end
end
