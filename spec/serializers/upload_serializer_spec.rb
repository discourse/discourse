# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UploadSerializer do
  fab!(:upload) { Fabricate(:upload) }
  let(:subject) { UploadSerializer.new(upload, root: false) }

  it 'should render without errors' do
    json_data = JSON.load(subject.to_json)

    expect(json_data['id']).to eql upload.id
    expect(json_data['width']).to eql upload.width
    expect(json_data['height']).to eql upload.height
    expect(json_data['thumbnail_width']).to eql upload.thumbnail_width
    expect(json_data['thumbnail_height']).to eql upload.thumbnail_height
  end

  context "when the upload is secure" do
    fab!(:upload) { Fabricate(:secure_upload) }

    context "when secure media is disabled" do
      it "just returns the normal URL, otherwise S3 errors are encountered" do
        json_data = JSON.load(subject.to_json)
        expect(json_data['url']).to eq(upload.url)
      end
    end

    context "when secure media is enabled" do
      before do
        enable_s3_uploads
        SiteSetting.secure_media = true
      end

      it "returns the cooked URL based on the upload URL" do
        UrlHelper.expects(:cook_url).with(upload.url, secure: true)
        subject.to_json
      end
    end
  end

  def enable_s3_uploads
    SiteSetting.s3_upload_bucket = "s3-upload-bucket"
    SiteSetting.s3_access_key_id = "s3-access-key-id"
    SiteSetting.s3_secret_access_key = "s3-secret-access-key"
    SiteSetting.s3_region = 'us-west-1'
    SiteSetting.enable_s3_uploads = true

    store = FileStore::S3Store.new
    s3_helper = store.instance_variable_get(:@s3_helper)
    client = Aws::S3::Client.new(stub_responses: true)
    s3_helper.stubs(:s3_client).returns(client)
    Discourse.stubs(:store).returns(store)
  end
end
