# frozen_string_literal: true

class AddGraphToPolls < ActiveRecord::Migration[6.0]
  def change
    add_column :polls, :chart, :boolean, default: false, null: false
  end
end
