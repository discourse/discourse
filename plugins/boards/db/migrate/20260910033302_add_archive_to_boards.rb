# frozen_string_literal: true

class AddArchiveToBoards < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_kanban_boards, :archived, :boolean, default: false, null: false
    add_column :discourse_kanban_boards, :archived_at, :datetime
    add_column :discourse_kanban_boards, :archived_by_id, :bigint
    add_column :discourse_kanban_boards, :original_slug, :string
  end
end
