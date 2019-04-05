require 'rails_helper'

describe Jobs::EnsurePostUploadsExistence do

  context '.execute' do
    let(:upload) { Fabricate(:upload) }
    let(:optimized) { Fabricate(:optimized_image, url: '/uploads/default/optimized/1X/d1c2d40ab994e8410c_100x200.png') }

    context "when enabled" do
      before do
        SiteSetting.enable_missing_post_uploads_check = true
      end

      it 'should create post custom field for missing upload' do
        Fabricate(:post, cooked: "A sample post <img src='#{upload.url}'>")
        upload.destroy!
        described_class.new.execute({})
        field = PostCustomField.find_by(name: Jobs::EnsurePostUploadsExistence::MISSING_UPLOADS)
        expect(field).to be_present
        expect(field.value).to eq(upload.url)
      end

      it 'should create post custom field with nil value' do
        Fabricate(:post, cooked: "A sample post <a href='#{upload.url}'> <img src='#{optimized.url}'>")
        described_class.new.execute({})
        field = PostCustomField.find_by(name: Jobs::EnsurePostUploadsExistence::MISSING_UPLOADS)
        expect(field).to be_present
        expect(field.value).to eq(nil)
      end
    end

    context "when disabled" do
      before do
        SiteSetting.enable_missing_post_uploads_check = false
      end

      it "does not execute" do
        Fabricate(:post, cooked: "A sample post <img src='#{upload.url}'>")
        upload.destroy!
        described_class.new.execute({})
        field = PostCustomField.find_by(name: Jobs::EnsurePostUploadsExistence::MISSING_UPLOADS)
        expect(field).to be_blank
      end
    end

  end
end
