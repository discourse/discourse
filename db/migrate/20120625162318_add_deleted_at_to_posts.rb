# frozen_string_literal: true

class AddDeletedAtToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :deleted_at, :datetime
  end
end
