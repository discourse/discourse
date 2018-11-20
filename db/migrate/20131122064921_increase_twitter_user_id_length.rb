class IncreaseTwitterUserIdLength < ActiveRecord::Migration[4.2]
  def change
    change_column :twitter_user_infos, :twitter_user_id, :bigint
  end
end
