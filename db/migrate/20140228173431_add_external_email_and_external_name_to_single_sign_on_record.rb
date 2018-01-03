class AddExternalEmailAndExternalNameToSingleSignOnRecord < ActiveRecord::Migration[4.2]
  def change
    add_column :single_sign_on_records, :external_email, :string
    add_column :single_sign_on_records, :external_name, :string
  end
end
