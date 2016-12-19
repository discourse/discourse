require_dependency 'sass/discourse_stylesheets'
require_dependency 'sass/discourse_sass_importer'
require_dependency 'sass/discourse_safe_sass_importer'

Rails.application.config.assets.configure do |env|
  env.register_transformer('text/sass', 'text/css',
    Sprockets::SassProcessor.new(importer: DiscourseSassImporter, sass_config: Rails.application.config.sass))
  env.register_transformer('text/scss', 'text/css',
    Sprockets::ScssProcessor.new(importer: DiscourseSassImporter, sass_config: Rails.application.config.sass))
end
