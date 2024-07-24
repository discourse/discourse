# frozen_string_literal: true

class DuplicateFlagsCustomTypeToRequireMessage < ActiveRecord::Migration[7.0]
  def up
    add_column :flags, :require_message, :boolean, default: false, null: false

    DB.exec <<~SQL
      UPDATE flags
      SET require_message = custom_type
    SQL
  end

  def down
    remove_column :flags, :require_message
  end
end
