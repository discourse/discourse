# frozen_string_literal: true

class AddRecurringToDiscoursePostEventInvitees < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_post_event_invitees, :recurring, :boolean, default: false, null: false
  end
end
