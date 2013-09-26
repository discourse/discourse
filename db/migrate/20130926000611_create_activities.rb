class CreateActivities < ActiveRecord::Migration
  def change
    create_table :activities do |t|
      t.belongs_to :user
      t.string :action
      t.references :trackable, :polymorphic => true

      t.timestamps
    end

    add_index :activities, :user_id
    add_index :activities, :trackable_id
  end
end
