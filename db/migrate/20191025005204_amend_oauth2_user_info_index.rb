# frozen_string_literal: true

class AmendOauth2UserInfoIndex < ActiveRecord::Migration[6.0]
  def up
    # remove old index which may have been unique
    execute "DROP INDEX index_oauth2_user_infos_on_user_id_and_provider"
    add_index :oauth2_user_infos, [:user_id, :provider]
  end
end
