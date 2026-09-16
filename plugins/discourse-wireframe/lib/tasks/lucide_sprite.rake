# frozen_string_literal: true

namespace :wireframe do
  desc "Regenerate the Lucide SVG sprite from svg-icons/lucide-icons.txt"
  task lucide_sprite: :environment do
    require_relative "../discourse_wireframe/lucide_sprite"

    names = DiscourseWireframe::LucideSprite.generate!
    puts "Wrote #{names.length} #{names.length == 1 ? "icon" : "icons"} " \
           "to #{DiscourseWireframe::LucideSprite::SPRITE_PATH}"
  end
end
