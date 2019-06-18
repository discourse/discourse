# frozen_string_literal: true

class AlterFacebookUserId < ActiveRecord::Migration[4.2]
  def up
    change_column :facebook_user_infos, :facebook_user_id, :integer, limit: 8, null: false
  end

  def down
    change_column :facebook_user_infos, :facebook_user_id, :integer, null: false
  end
end
