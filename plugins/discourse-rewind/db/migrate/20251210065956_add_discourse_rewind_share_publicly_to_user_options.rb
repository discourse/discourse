# frozen_string_literal: true

class AddDiscourseRewindSharePubliclyToUserOptions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :discourse_rewind_share_publicly, :boolean, default: true, null: false
  end
end
