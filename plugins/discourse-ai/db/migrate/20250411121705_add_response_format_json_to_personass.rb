# frozen_string_literal: true
class AddResponseFormatJsonToPersonass < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_personas, :response_format, :jsonb
  end
end
