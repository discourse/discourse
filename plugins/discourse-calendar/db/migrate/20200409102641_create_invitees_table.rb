# frozen_string_literal: true

class CreateInviteesTable < ActiveRecord::Migration[5.2]
  def up
    unless ActiveRecord::Base.connection.table_exists?("discourse_calendar_invitees")
      create_table :discourse_calendar_invitees do |t|
        t.integer :post_id, null: false
        t.integer :user_id, null: false
        t.integer :status
        t.timestamps null: false
        t.boolean :notified, null: false, default: false
      end

      add_index :discourse_calendar_invitees, %i[post_id user_id], unique: true
    end
  end

  def down
    drop_table :discourse_calendar_invitees
  end
end
