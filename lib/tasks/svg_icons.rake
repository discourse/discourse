# frozen_string_literal: true

desc "Vendor the icon package's sprites from node_modules, keeping dropped icon names renderable"
task "svgicons:sync" do
  require_relative "../svg_sprite/font_awesome_sync"

  sync = SvgSprite::FontAwesomeSync.new
  stale_files = sync.stale_files
  sync.write!

  if stale_files.empty?
    puts "Sprites are already up to date"
  else
    stale_files.each { |path| puts "Updated #{path.relative_path_from(Rails.root)}" }
  end
end

desc "Install JS packages, then run svgicons:sync"
task "svgicons:update" do
  system("pnpm install", exception: true)
  Rake::Task["svgicons:sync"].invoke
end
