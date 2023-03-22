# frozen_string_literal: true

class DropNotNull < ActiveRecord::Migration[5.1]
  def up
    change_column_null :users, :username, false
  end

  def down
    raise "not tested"
  end
end
