class ChangeDatatypeOnSingleSignOnRecordsFromStringToText < ActiveRecord::Migration
  def up
    change_column :single_sign_on_records, :external_avatar_url, :text, :limit => nil
  end

  def down
    change_column :single_sign_on_records, :external_avatar_url, :string
  end
end
