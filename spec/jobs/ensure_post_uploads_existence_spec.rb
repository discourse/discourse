require 'rails_helper'

describe Jobs::EnsurePostUploadsExistence do

  context '.execute' do
    let(:upload) { Fabricate(:upload) }
    let(:optimized) { Fabricate(:optimized_image, url: '/uploads/default/optimized/1X/d1c2d40ab994e8410c_100x200.png') }

    it 'should create post custom field for missing upload' do
      post = Fabricate(:post, cooked: "A sample post <img src='#{upload.url}'>")
      upload.destroy!
      described_class.new.execute({})
      field = PostCustomField.last
      expect(field.name).to eq(Jobs::EnsurePostUploadsExistence::MISSING_UPLOADS)
      expect(field.value).to eq(upload.url)
    end

    it 'should create post custom field with nil value' do
      post = Fabricate(:post, cooked: "A sample post <a href='#{upload.url}'> <img src='#{optimized.url}'>")
      described_class.new.execute({})
      field = PostCustomField.last
      expect(field.name).to eq(Jobs::EnsurePostUploadsExistence::MISSING_UPLOADS)
      expect(field.value).to eq(nil)
    end
  end
end
