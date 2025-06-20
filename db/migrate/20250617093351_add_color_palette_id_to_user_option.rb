# frozen_string_literal: true

class AddColorPaletteIdToUserOption < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :color_palette_id, :integer
  end
end
