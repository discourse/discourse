require_dependency 'sass/discourse_stylesheets'
require_dependency 'sass/discourse_sass_importer'
require_dependency 'sass/discourse_safe_sass_importer'

Sprockets.send(:remove_const, :SassImporter)
Sprockets::SassImporter = DiscourseSassImporter
