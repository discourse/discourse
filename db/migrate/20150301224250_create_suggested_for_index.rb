class CreateSuggestedForIndex < ActiveRecord::Migration
  def change
    add_index :topics, [:created_at, :visible],
                where: "deleted_at IS NULL AND archetype <> 'private_message'"
  end
end
