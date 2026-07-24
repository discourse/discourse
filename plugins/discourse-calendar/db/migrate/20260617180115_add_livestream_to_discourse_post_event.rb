# frozen_string_literal: true

class AddLivestreamToDiscoursePostEvent < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_post_event_events, :livestream, :boolean, null: false, default: false
  end
end
