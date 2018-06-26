class AddExternalProfileAndCardBackgroundUrlToSingleSignOnRecord < ActiveRecord::Migration[5.1]
  def change
    add_column :single_sign_on_records, :external_profile_background_url, :string
    add_column :single_sign_on_records, :external_card_background_url, :string
  end
end
