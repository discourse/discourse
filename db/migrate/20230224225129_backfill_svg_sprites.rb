# frozen_string_literal: true

class BackfillSvgSprites < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    ThemeSvgSprite.refetch!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
