# frozen_string_literal: true

class AddScoreBonusToPostActionTypes < ActiveRecord::Migration[5.2]
  def change
    add_column :post_action_types, :score_bonus, :float, default: 0.0, null: false
  end
end
