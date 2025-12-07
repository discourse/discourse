# frozen_string_literal: true

class AddDiscourseRewindDisabledToUserOptions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :discourse_rewind_disabled, :boolean, default: false, null: false
  end
end

