# frozen_string_literal: true

class AddGraphToPolls < ActiveRecord::Migration[6.0]
  def change
    add_column :polls, :chart_type, :integer, default: 0, null: false
  end
end
