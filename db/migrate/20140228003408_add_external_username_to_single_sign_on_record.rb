class AddExternalUsernameToSingleSignOnRecord < ActiveRecord::Migration
  def change
    add_column :single_sign_on_records, :username, :string
  end
end
