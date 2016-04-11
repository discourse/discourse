require_dependency 'sass/discourse_stylesheets'
require_dependency 'sass/discourse_sass_importer'
require_dependency 'sass/discourse_safe_sass_importer'

DiscourseSassTemplate = Class.new(Sass::Rails::SassTemplate) do
  def importer_class
    DiscourseSassImporter
  end
end
DiscourseScssTemplate = Class.new(DiscourseSassTemplate) do
  def syntax
    :scss
  end
end

Rails.application.config.assets.configure do |env|
  env.register_engine '.sass', DiscourseSassTemplate
  env.register_engine '.scss', DiscourseScssTemplate
end
