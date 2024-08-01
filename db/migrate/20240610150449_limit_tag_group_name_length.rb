# frozen_string_literal: true

class LimitTagGroupNameLength < ActiveRecord::Migration[7.0]
  def change
    DB.exec <<~SQL
      UPDATE tag_groups 
      SET name = LEFT(name, 100)
      WHERE LENGTH(name) > 100
    SQL

    change_column :tag_groups, :name, :string, limit: 100
  end
end
