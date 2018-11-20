class AddSequenceToDrafts < ActiveRecord::Migration[4.2]
  def change
    add_column :drafts, :sequence, :integer, null: false, default: 0
  end
end
