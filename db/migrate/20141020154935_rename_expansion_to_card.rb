class RenameExpansionToCard < ActiveRecord::Migration
  def change
    rename_column :user_profiles, :expansion_background, :card_background
  end
end
