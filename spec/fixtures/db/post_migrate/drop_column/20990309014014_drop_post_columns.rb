# frozen_string_literal: true

class DropPostColumns < ActiveRecord::Migration[5.2]
  DROPPED_COLUMNS ||= {
    posts: %i{via_email raw_email}
  }

  def up
    remove_column :posts, :via_email
    remove_column :posts, :raw_email
    raise ActiveRecord::Rollback
  end

  def down
    raise "not tested"
  end
end
