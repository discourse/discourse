# frozen_string_literal: true

class ThemeSvgSprite < ActiveRecord::Base
  belongs_to :theme
end

# == Schema Information
#
# Table name: theme_svg_sprites
#
#  id         :bigint           not null, primary key
#  theme_id   :integer          not null
#  upload_id  :integer          not null
#  sprite     :string(4194304)  not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_theme_svg_sprites_on_theme_id  (theme_id) UNIQUE
#
