# frozen_string_literal: true

class AddImagesToAiPersonas < ActiveRecord::Migration[7.0]
  def change
    change_table :ai_personas do |t|
      add_column :ai_personas, :vision_enabled, :boolean, default: false, null: false
      add_column :ai_personas, :vision_max_pixels, :integer, default: 1_048_576, null: false
    end
  end
end
