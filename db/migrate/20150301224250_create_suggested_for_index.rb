# frozen_string_literal: true

class CreateSuggestedForIndex < ActiveRecord::Migration[4.2]
  def change
    add_index :topics, [:created_at, :visible],
                where: "deleted_at IS NULL AND archetype <> 'private_message'"
  end
end
