module AnnotatorStore
  RSpec.describe Annotation, type: :model do
    let(:annotation) { FactoryGirl.create :annotator_store_annotation }

    it 'has a valid factory' do
      expect(annotation).to be_valid
    end
  end
end
