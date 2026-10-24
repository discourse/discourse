# frozen_string_literal: true
class AddDeletedAtToDrafts < ActiveRecord::Migration[8.1]
  def change
    add_column :drafts, :deleted_at, :datetime
  end
end
