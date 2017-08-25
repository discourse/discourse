module AnnotatorStore
  RSpec.describe 'Pages', type: :request do
    describe 'GET /' do
      it 'returns response status 200' do
        get annotator_store.root_path
        expect(response).to have_http_status(200)
      end
    end

    describe 'GET /search' do
      it 'returns response status 200' do
        get annotator_store.search_path
        expect(response).to have_http_status(200)
      end
    end
  end
end
