# frozen_string_literal: true

class ThemeSvgSprite < ActiveRecord::Base
  belongs_to :theme

  def self.refetch!
    ThemeField.svg_sprite_fields.find_each(&:upsert_svg_sprite!)
    SvgSprite.expire_cache
  end
end

# == Schema Information
#
# Table name: theme_svg_sprites
#
#  id         :bigint           not null, primary key
#  theme_id   :integer          not null
#  upload_id  :integer          not null
#  sprite     :binary           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_theme_svg_sprites_on_theme_id  (theme_id) UNIQUE
#
