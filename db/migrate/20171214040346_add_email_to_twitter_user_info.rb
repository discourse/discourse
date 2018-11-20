class AddEmailToTwitterUserInfo < ActiveRecord::Migration[5.1]
  def change
    add_column :twitter_user_infos, :email, :string, limit: 1000, null: true
  end
end
