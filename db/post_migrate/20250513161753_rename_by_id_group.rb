# frozen_string_literal: true
class RenameByIdGroup < ActiveRecord::Migration[7.2]
  def change
    execute <<~SQL
      UPDATE groups
      SET name = 'by-id1'
      WHERE name = 'by-id'
        AND NOT EXISTS (
          SELECT 1 FROM groups WHERE name = 'by-id1'
        );
    SQL
  end
end
