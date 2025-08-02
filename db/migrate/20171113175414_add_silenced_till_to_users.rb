# frozen_string_literal: true

class AddSilencedTillToUsers < ActiveRecord::Migration[5.1]
  def up
    add_column :users, :silenced_till, :timestamp, null: true
    execute <<~SQL
      UPDATE users
        SET silenced_till = CURRENT_TIMESTAMP + INTERVAL '1000 YEAR'
        WHERE silenced
    SQL
  end

  def down
    add_column :users, :silenced_till
  end
end
