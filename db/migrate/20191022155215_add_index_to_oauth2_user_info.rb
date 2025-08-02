# frozen_string_literal: true

class AddIndexToOauth2UserInfo < ActiveRecord::Migration[6.0]
  def change
    add_index :oauth2_user_infos, %i[user_id provider]
  end
end
