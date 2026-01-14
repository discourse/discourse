# frozen_string_literal: true

class AddSystemAndPriorityToAiPersonas < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_personas, :system, :boolean, null: false, default: false
    add_column :ai_personas, :priority, :boolean, null: false, default: false
  end
end
