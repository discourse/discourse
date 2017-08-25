module AnnotatorStore
  RSpec.describe PagesController, type: :routing do
    routes { AnnotatorStore::Engine.routes }

    describe 'routing' do
      it 'routes GET / to #index' do
        expect(get: '/').to route_to('annotator_store/pages#index', format: :json)
      end

      it 'routes GET /search to #search' do
        expect(get: '/search').to route_to('annotator_store/pages#search', format: :json)
      end
    end
  end
end
