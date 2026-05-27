# frozen_string_literal: true

class AddDiscourseRewindDismissedAtToUserOptions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :discourse_rewind_dismissed_at, :datetime, null: true
  end
end
