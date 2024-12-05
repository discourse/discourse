# frozen_string_literal: true
class RemapFa5IconNamesToFa6 < ActiveRecord::Migration[7.1]
  def up
    # no-op - reimplemented in 20241204085540_remap_to_fa6_icon_names.rb
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
