class CreateGroupRequests < ActiveRecord::Migration[5.2]
  def change
    create_table :group_requests do |t|
      t.integer :group_id
      t.integer :user_id
      t.string :reason

      t.timestamps
    end
  end
end
