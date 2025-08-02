# frozen_string_literal: true

class AddRequirementToUserFields < ActiveRecord::Migration[7.0]
  def up
    add_column :user_fields, :requirement, :integer, null: false, default: 0

    execute <<~SQL
      UPDATE user_fields
      SET requirement =
        (CASE WHEN required IS NOT TRUE THEN 0 ELSE 2 END)
    SQL
  end

  def down
    remove_column :user_fields, :requirement
  end
end
