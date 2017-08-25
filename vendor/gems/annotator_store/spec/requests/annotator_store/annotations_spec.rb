module AnnotatorStore
  RSpec.describe 'Annotations', type: :request do
    let(:annotation) { FactoryGirl.create :annotator_store_annotation }

    describe 'POST /annotations' do
      let(:valid_params) do
        {
          annotator_schema_version: "v#{Faker::App.version}",
          text: Faker::Lorem.sentence,
          quote: Faker::Lorem.sentence,
          uri: Faker::Internet.url,
          ranges: [
            {
              start: '/p[69]/span/span',
              end: '/p[70]/span/span',
              startOffset: 0,
              endOffset: 120
            }
          ]
        }
      end

      it 'returns response status 201' do
        parameters = valid_params
        parameters[:format] = :json
        post annotator_store.annotations_path, parameters
        expect(response).to have_http_status(201)
      end
    end

    describe 'GET /annotations/1' do
      it 'returns response status 200' do
        get annotator_store.annotation_path(annotation)
        expect(response).to have_http_status(200)
      end
    end

    describe 'PUT /annotations/1' do
      let(:new_params) do
        {
          annotator_schema_version: "v#{Faker::App.version}",
          text: Faker::Lorem.sentence,
          quote: Faker::Lorem.sentence,
          uri: Faker::Internet.url
        }
      end

      it 'returns response status 200' do
        parameters = new_params
        parameters[:format] = :json
        put annotator_store.annotation_path(annotation), parameters
        expect(response).to have_http_status(200)
      end
    end

    describe 'DELETE /annotations/1' do
      it 'returns response status 204' do
        delete annotator_store.annotation_path(annotation)
        expect(response).to have_http_status(204)
      end

      it 'returns no body' do
        delete annotator_store.annotation_path(annotation)
        expect(response.body.length).to eq 0
      end
    end
  end
end
