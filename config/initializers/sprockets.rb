require_dependency 'discourse_sass_importer'

Sprockets.send(:remove_const, :SassImporter)
Sprockets::SassImporter = DiscourseSassImporter
