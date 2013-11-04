task 'assets:precompile' => 'environment' do
  # see: https://github.com/rails/sprockets-rails/issues/49
  # a decision was made no longer to copy non-digested assets
  # this breaks stuff like the emoji plugin. We could fix it,
  # but its a major pain with little benefit.
  if rails4?
    puts "> Copying non-digested versions of assets"
    assets = Dir.glob(File.join(Rails.root, 'public/assets/**/*'))
    regex = /(-{1}[a-z0-9]{32}*\.{1}){1}/
    assets.each do |file|
      next if File.directory?(file) || file !~ regex

      source = file.split('/')
      source.push(source.pop.gsub(regex, '.'))

      non_digested = File.join(source)
      FileUtils.cp(file, non_digested)
    end
    puts "> Removing cache"
    `rm -fr tmp/cache`
  end
end
