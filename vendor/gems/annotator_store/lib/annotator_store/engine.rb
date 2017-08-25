module AnnotatorStore
  class Engine < ::Rails::Engine
    isolate_namespace AnnotatorStore

    config.generators do |g|
      g.integration_tool :rspec
      g.test_framework :rspec, fixture: false
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
    end
  end
end
