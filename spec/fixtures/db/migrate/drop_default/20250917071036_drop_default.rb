# frozen_string_literal: true
class DropDefault < ActiveRecord::Migration[8.0]
  def up
    change_column_default :posts, :like_count, nil
  end

  def down
    raise "not tested"
  end
end
