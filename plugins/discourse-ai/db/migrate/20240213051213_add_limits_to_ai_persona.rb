# frozen_string_literal: true

class AddLimitsToAiPersona < ActiveRecord::Migration[7.0]
  def change
    change_table :ai_personas do |t|
      t.integer :max_context_posts, null: true
    end
  end
end
