# frozen_string_literal: true

class AddPrefersEncryptFieldToPendingPms < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_automation_pending_pms, :prefers_encrypt, :boolean, default: false

    execute <<~SQL
      UPDATE discourse_automation_pending_pms
      SET prefers_encrypt = false
    SQL

    change_column_null :discourse_automation_pending_pms, :prefers_encrypt, false
  end
end
