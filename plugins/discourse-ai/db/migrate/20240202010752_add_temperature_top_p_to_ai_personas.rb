# frozen_string_literal: true

class AddTemperatureTopPToAiPersonas < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_personas, :temperature, :float, null: true
    add_column :ai_personas, :top_p, :float, null: true
  end
end
