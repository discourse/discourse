class AddSequenceToDrafts < ActiveRecord::Migration
  def change
    add_column :drafts, :sequence, :integer, null: false, default: 0
  end
end
