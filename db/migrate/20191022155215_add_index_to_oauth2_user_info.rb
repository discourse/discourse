# frozen_string_literal: true

class AddIndexToOauth2UserInfo < ActiveRecord::Migration[6.0]
  def change
    add_index :oauth2_user_infos, [:user_id, :provider], unique: true
  end
end
