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

desc "Fail if the vendored sprites don't match the icon package in node_modules"
task "svgicons:check" do
  require_relative "../svg_sprite/font_awesome_sync"

  stale_files = SvgSprite::FontAwesomeSync.new.stale_files
  next puts "Sprites are up to date" if stale_files.empty?

  stale_files.each { |path| puts "Out of date: #{path.relative_path_from(Rails.root)}" }
  abort "Vendored icon sprites don't match node_modules, run `bin/rake svgicons:update`"
end

desc "Install JS packages, then run svgicons:sync"
task "svgicons:update" do
  system("pnpm install", exception: true)
  Rake::Task["svgicons:sync"].invoke
end
