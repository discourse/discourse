# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Enable the asset pipeline
Rails.application.config.assets.enabled = true

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "2-#{GlobalSetting.asset_url_salt}"

# Add additional assets to the asset load path.
Rails.application.config.assets.paths << "#{Rails.root}/public/javascripts"

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.

# explicitly precompile any images in plugins ( /assets/images ) path
Rails.application.config.assets.precompile += [
  lambda do |filename, path|
    path =~ %r{assets/images} && !%w[.js .css].include?(File.extname(filename))
  end,
]

Rails.application.config.assets.precompile += %w[break_string.js scripts/discourse-test-listen-boot]

Rails.application.config.assets.precompile << lambda do |logical_path, filename|
  filename.start_with?(EmberCli.dist_dir) && EmberCli.assets.include?(logical_path)
end

# out of the box sprockets 3 grabs loose files that are hanging in assets,
# the exclusion list does not include hbs so you double compile all this stuff
Rails.application.config.assets.precompile.delete(Sprockets::Railtie::LOOSE_APP_ASSETS)

# We don't want application from node_modules, only from the root
Rails.application.config.assets.precompile.delete(%r{(?:/|\\|\A)application\.(css|js)$})

Discourse
  .find_plugin_js_assets(include_disabled: true)
  .each do |file|
    Rails.application.config.assets.precompile << "#{file}.js" if file.end_with?("_extra")
  end
