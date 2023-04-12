# frozen_string_literal: true

class AddPrefersEncryptFieldToPendingPms < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_automation_pending_pms,
               :prefers_encrypt,
               :boolean,
               null: false,
               default: false
  end
end
