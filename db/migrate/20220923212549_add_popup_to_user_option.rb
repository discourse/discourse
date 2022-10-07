# frozen_string_literal: true

class AddPopupToUserOption < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :skip_first_notification_tips, :boolean, default: false
  end
end
