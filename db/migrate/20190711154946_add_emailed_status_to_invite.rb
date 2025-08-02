# frozen_string_literal: true

class AddEmailedStatusToInvite < ActiveRecord::Migration[5.2]
  def change
    add_column :invites, :emailed_status, :integer
    add_index :invites, :emailed_status

    DB.exec <<~SQL
      UPDATE invites
      SET emailed_status = 0
      WHERE via_email = false
    SQL
  end
end
