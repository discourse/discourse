# frozen_string_literal: true

class AddNameToUserSecondFactors < ActiveRecord::Migration[5.2]
  def change
    add_column :user_second_factors, :name, :string
  end
end
