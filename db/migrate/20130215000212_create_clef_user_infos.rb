class CreateClefUserInfos < ActiveRecord::Migration
  def change
    create_table :clef_user_infos do |t|
      t.integer :user_id, null: false
      t.integer :clef_user_id, null: false
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :name

      t.timestamps
    end
    add_index :clef_user_infos, :user_id, unique: true
    add_index :clef_user_infos, :clef_user_id, unique: true
  end
end
