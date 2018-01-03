class CreateTopicInvites < ActiveRecord::Migration[4.2]
  def change
    create_table :topic_invites do |t|
      t.references :topic, null: false
      t.references :invite, null: false
      t.timestamps null: false
    end

    add_index :topic_invites, [:topic_id, :invite_id], unique: true
    add_index :topic_invites, :invite_id
  end
end
