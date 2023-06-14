# frozen_string_literal: true

class RemoveOldPollsDataFromCustomFields < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
    DELETE FROM post_custom_fields
    WHERE name LIKE 'polls%'
    SQL
  end

  def down
  end
end
