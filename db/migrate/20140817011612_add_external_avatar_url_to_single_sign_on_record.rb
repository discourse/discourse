class AddExternalAvatarUrlToSingleSignOnRecord < ActiveRecord::Migration[4.2]
  def change
    add_column :single_sign_on_records, :external_avatar_url, :string
  end
end
