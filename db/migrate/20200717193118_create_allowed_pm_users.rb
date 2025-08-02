# frozen_string_literal: true
class CreateAllowedPmUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :allowed_pm_users do |t|
      t.integer :user_id, null: false
      t.integer :allowed_pm_user_id, null: false
      t.timestamps null: false
    end

    add_index :allowed_pm_users, %i[user_id allowed_pm_user_id], unique: true
    add_index :allowed_pm_users, %i[allowed_pm_user_id user_id], unique: true
  end
end
