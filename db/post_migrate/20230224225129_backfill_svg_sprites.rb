# frozen_string_literal: true

class BackfillSvgSprites < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    ThemeField.svg_sprite_fields.find_each(&:upsert_svg_sprite!)
    DB.after_commit { SvgSprite.expire_cache }
  end
end
