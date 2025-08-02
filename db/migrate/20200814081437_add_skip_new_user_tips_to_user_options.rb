# frozen_string_literal: true

class AddSkipNewUserTipsToUserOptions < ActiveRecord::Migration[6.0]
  def change
    add_column :user_options, :skip_new_user_tips, :boolean, default: false, null: false
  end
end
