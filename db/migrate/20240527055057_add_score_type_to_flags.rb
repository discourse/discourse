# frozen_string_literal: true

class AddScoreTypeToFlags < ActiveRecord::Migration[7.0]
  def change
    add_column(:flags, :score_type, :boolean, default: false, null: false)
  end
end
