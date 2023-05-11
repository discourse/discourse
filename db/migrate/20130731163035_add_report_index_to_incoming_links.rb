# frozen_string_literal: true

class AddReportIndexToIncomingLinks < ActiveRecord::Migration[4.2]
  def change
    add_index :incoming_links, %i[created_at user_id]
    add_index :incoming_links, %i[created_at domain]
  end
end
