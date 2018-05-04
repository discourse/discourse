class CreatePushSubscription < ActiveRecord::Migration[5.1]
  def change
    create_table :push_subscriptions do |t|
      t.integer :user_id, null: false
      t.string :data, null: false
      t.timestamps
    end
  end
end
