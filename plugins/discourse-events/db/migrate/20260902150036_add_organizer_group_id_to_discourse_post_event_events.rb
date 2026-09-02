# frozen_string_literal: true
class AddOrganizerGroupIdToDiscoursePostEventEvents < ActiveRecord::Migration[8.0]
  def up
    add_column :discourse_post_event_events, :organizer_group_id, :bigint
    add_index :discourse_post_event_events, :organizer_group_id
  end

  def down
    remove_column :discourse_post_event_events, :organizer_group_id
  end
end
