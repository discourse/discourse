# frozen_string_literal: true

class BackfillSvgSprites < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    ThemeSvgSprite.refetch!
  end
end
