# frozen_string_literal: true

class RemoveSeedColorScheme < ActiveRecord::Migration[4.2]
  def up
    execute "DELETE FROM color_schemes WHERE id = 1"
    execute "DELETE FROM color_scheme_colors WHERE color_scheme_id = 1"
  end

  def down
  end
end
