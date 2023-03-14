# frozen_string_literal: true

task "svg_sprites:refetch" => [:environment] do |_, args|
  ThemeSvgSprite.refetch!
end
