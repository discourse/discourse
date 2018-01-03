class SingleSignOnIncreaseExternalAvatarUrl < ActiveRecord::Migration[4.2]
  def change
    change_column :single_sign_on_records, :external_avatar_url, :string, limit: 1000
  end
end
