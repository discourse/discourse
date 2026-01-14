# frozen_string_literal: true

class AddExamplesToPersonas < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_personas, :examples, :jsonb
  end
end
