module AnnotatorStore
  RSpec.describe Range, type: :model do
    let(:range) { FactoryGirl.create :annotator_store_range }

    it 'has a valid factory' do
      expect(range).to be_valid
    end
  end
end
