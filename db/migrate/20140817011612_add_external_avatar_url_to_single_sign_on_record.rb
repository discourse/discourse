class AddExternalAvatarUrlToSingleSignOnRecord < ActiveRecord::Migration
  def change
    add_column :single_sign_on_records, :external_avatar_url, :string
  end
end
