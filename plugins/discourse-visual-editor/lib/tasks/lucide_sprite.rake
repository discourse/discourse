# frozen_string_literal: true

namespace :visual_editor do
  desc "Regenerate the Lucide SVG sprite from svg-icons/lucide-icons.txt"
  task lucide_sprite: :environment do
    require_relative "../discourse_visual_editor/lucide_sprite"

    names = DiscourseVisualEditor::LucideSprite.generate!
    puts "Wrote #{names.length} #{names.length == 1 ? "icon" : "icons"} " \
           "to #{DiscourseVisualEditor::LucideSprite::SPRITE_PATH}"
  end
end
