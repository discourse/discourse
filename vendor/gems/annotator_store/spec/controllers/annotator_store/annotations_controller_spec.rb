module AnnotatorStore
  RSpec.describe AnnotationsController, type: :controller do
    routes { AnnotatorStore::Engine.routes }

    let(:annotation) { FactoryGirl.create :annotator_store_annotation }
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

    describe 'GET show' do
      it 'assigns the requested annotation as @annotation' do
        get :show, id: annotation.to_param, format: :json
        expect(assigns(:annotation)).to eq(annotation)
      end
    end

    describe 'POST create' do
      describe 'with valid params' do
        it 'creates a new AnnotatorStore::Annotation' do
          expect do
            parameters = valid_params
            parameters[:format] = :json
            post :create, parameters
          end.to change(AnnotatorStore::Annotation, :count).by(1)
        end

        it 'assigns a newly created annotation as @annotation' do
          parameters = valid_params
          parameters[:format] = :json
          post :create, parameters
          expect(assigns(:annotation)).to be_a(AnnotatorStore::Annotation)
          expect(assigns(:annotation)).to be_persisted
        end
      end
    end

    describe 'PUT update' do
      describe 'with valid params' do
        let(:new_params) do
          {
            annotator_schema_version: "v#{Faker::App.version}",
            text: Faker::Lorem.sentence,
            quote: Faker::Lorem.sentence,
            uri: Faker::Internet.url
          }
        end

        it 'updates the requested annotation' do
          parameters = new_params
          parameters[:id] = annotation.to_param
          parameters[:format] = :json
          put :update, parameters
          annotation.reload
          expect(annotation.version).to eq(new_params[:annotator_schema_version])
          expect(annotation.text).to eq(new_params[:text])
          expect(annotation.quote).to eq(new_params[:quote])
          expect(annotation.uri).to eq(new_params[:uri])
        end

        it 'assigns the requested annotation as @annotation' do
          parameters = new_params
          parameters[:id] = annotation.to_param
          parameters[:format] = :json
          put :update, parameters
          expect(assigns(:annotation)).to eq(annotation)
        end
      end
    end

    describe 'DELETE destroy' do
      it 'destroys the requested annotation' do
        annotation
        expect do
          delete :destroy, id: annotation.to_param, format: :json
        end.to change(AnnotatorStore::Annotation, :count).by(-1)
      end
    end
  end
end
