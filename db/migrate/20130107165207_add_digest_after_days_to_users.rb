class AddDigestAfterDaysToUsers < ActiveRecord::Migration
  def change
    add_column :users, :digest_after_days, :integer, default: 7, null: false
  end
end
