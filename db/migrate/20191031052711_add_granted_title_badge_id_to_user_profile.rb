# frozen_string_literal: true

class AddGrantedTitleBadgeIdToUserProfile < ActiveRecord::Migration[6.0]
  def up
    add_reference :user_profiles, :granted_title_badge, foreign_key: { to_table: :badges }, index: true, null: true
  end

  def down
    remove_column :user_profiles, :granted_title_badge_id
  end
end
