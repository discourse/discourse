# frozen_string_literal: true

class IncreaseSizeOfTagDescriptions < ActiveRecord::Migration[7.0]
  def change
    change_column :tags, :description, :string, limit: 1000
  end
end
