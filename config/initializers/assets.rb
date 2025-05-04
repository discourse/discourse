# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Enable the asset pipeline
Rails.application.config.assets.enabled = true

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "2-#{GlobalSetting.asset_url_salt}"

# Add additional assets to the asset load path.
Rails.application.config.assets.paths.push(
  "#{Rails.root}/public/javascripts",
  "#{Rails.root}/app/assets/javascripts/discourse/dist/assets",
)

Rails.application.config.assets.paths.push(
  *Discourse.plugins.map { |p| "#{Rails.root}/app/assets/generated/#{p.directory_name}" },
)

# These paths are added automatically by propshaft, but we don't want them
Rails.application.config.assets.excluded_paths.push(
  "#{Rails.root}/app/assets/generated",
  "#{Rails.root}/app/assets/javascripts",
  "#{Rails.root}/app/assets/stylesheets",
)

# We don't need/want most of Propshaft's preprocessing. Only keep the JS sourcemap handler
Rails.application.config.assets.compilers.filter! do |type, compiler|
  type == "text/javascript" && compiler == Propshaft::Compiler::SourceMappingUrls
end
