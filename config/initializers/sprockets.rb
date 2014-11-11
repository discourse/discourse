require_dependency 'sass/discourse_stylesheets'
require_dependency 'sass/discourse_sass_importer'
require_dependency 'sass/discourse_safe_sass_importer'

if defined?(Sass::Rails::SassTemplate)
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
  Rails.application.assets.register_engine '.sass', DiscourseSassTemplate
  Rails.application.assets.register_engine '.scss', DiscourseScssTemplate
else
  Sprockets.send(:remove_const, :SassImporter)
  Sprockets::SassImporter = DiscourseSassImporter
end
