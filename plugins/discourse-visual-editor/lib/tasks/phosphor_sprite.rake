# frozen_string_literal: true

namespace :visual_editor do
  desc "Regenerate the Phosphor SVG sprite from svg-icons/phosphor-icons.txt"
  task phosphor_sprite: :environment do
    require_relative "../discourse_visual_editor/phosphor_sprite"

    names = DiscourseVisualEditor::PhosphorSprite.generate!
    puts "Wrote #{names.length} #{names.length == 1 ? "icon" : "icons"} " \
           "to #{DiscourseVisualEditor::PhosphorSprite::SPRITE_PATH}"
  end
end
