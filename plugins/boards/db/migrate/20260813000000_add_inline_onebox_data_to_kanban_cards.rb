# frozen_string_literal: true

class AddInlineOneboxDataToKanbanCards < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_kanban_cards, :inline_onebox_data, :jsonb
  end
end
