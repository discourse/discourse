# frozen_string_literal: true

class RenameExpansionToCard < ActiveRecord::Migration[4.2]
  def change
    rename_column :user_profiles, :expansion_background, :card_background
  end
end
