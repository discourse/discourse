# frozen_string_literal: true

task "svg_sprites:refetch" => [:environment] do |_, args|
  ThemeField.svg_sprite_fields.find_each(&:upsert_svg_sprite!)
end
