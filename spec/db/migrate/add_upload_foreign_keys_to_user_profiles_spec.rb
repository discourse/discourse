require 'rails_helper'
require 'migration/column_dropper'
require_relative '../../../db/migrate/20190426011148_add_upload_foreign_keys_to_user_profiles'

RSpec.describe AddUploadForeignKeysToUserProfiles do
  before do
    %i{card_background profile_background}.each do |column|
      # In the future when the column is dropped
      # DB.exec("ALTER TABLE user_profiles ADD COLUMN #{column} VARCHAR;")
      Migration::ColumnDropper.drop_readonly(:user_profiles, column)
    end

    %i{card_background_upload_id profile_background_upload_id}.each do |column|
      DB.exec("ALTER TABLE user_profiles DROP COLUMN IF EXISTS #{column}")
    end
  end

  def select_column_from_user_profiles(column, user_id)
    DB.query_single(<<~SQL).first
    SELECT #{column}
    FROM user_profiles
    WHERE user_id = #{user_id}
    SQL
  end

  it "should migrate the data properly" do
    upload = Fabricate(:upload)
    upload2 = Fabricate(:upload)
    user = Fabricate(:user)
    user2 = Fabricate(:user)
    user3 = Fabricate(:user)

    DB.exec(<<~SQL)
    UPDATE user_profiles
    SET card_background = '#{upload.url}', profile_background = '#{upload.url}'
    WHERE user_profiles.user_id = #{user.id}
    SQL

    DB.exec(<<~SQL)
    UPDATE user_profiles
    SET card_background = '#{upload.url}', profile_background = '#{upload2.url}'
    WHERE user_profiles.user_id = #{user2.id}
    SQL

    DB.exec(<<~SQL)
    UPDATE user_profiles
    SET card_background = '#{upload.url}'
    WHERE user_profiles.user_id = #{user3.id}
    SQL

    silence_stdout { described_class.new.up }

    %i{card_background profile_background}.each do |column|
      expect(select_column_from_user_profiles(column, user.id))
        .to eq(upload.url)
    end

    %i{card_background_upload_id profile_background_upload_id}.each do |column|
      expect(select_column_from_user_profiles(column, user.id))
        .to eq(upload.id)
    end

    expect(select_column_from_user_profiles(
      :card_background_upload_id, user2.id
    )).to eq(upload.id)

    expect(select_column_from_user_profiles(
      :profile_background_upload_id, user2.id
    )).to eq(upload2.id)

    expect(select_column_from_user_profiles(
      :card_background_upload_id, user3.id
    )).to eq(upload.id)

    expect(select_column_from_user_profiles(
      :profile_background_upload_id, user3.id
    )).to eq(nil)
  end
end
