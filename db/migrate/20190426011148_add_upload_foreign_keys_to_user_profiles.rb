# frozen_string_literal: true

require 'migration/column_dropper'

class AddUploadForeignKeysToUserProfiles < ActiveRecord::Migration[5.2]
  def up
    %i{profile_background card_background}.each do |column|
      Migration::ColumnDropper.mark_readonly(:user_profiles, column)
    end

    add_column :user_profiles, :profile_background_upload_id, :integer, null: true
    add_column :user_profiles, :card_background_upload_id, :integer, null: true
    add_foreign_key :user_profiles, :uploads, column: :profile_background_upload_id
    add_foreign_key :user_profiles, :uploads, column: :card_background_upload_id

    execute <<~SQL
    UPDATE user_profiles up1
    SET profile_background_upload_id = u.id
    FROM user_profiles up2
    INNER JOIN uploads u ON u.url = up2.profile_background
    WHERE up1.user_id = up2.user_id
    SQL

    execute <<~SQL
    UPDATE user_profiles up1
    SET card_background_upload_id = u.id
    FROM user_profiles up2
    INNER JOIN uploads u ON u.url = up2.card_background
    WHERE up1.user_id = up2.user_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
