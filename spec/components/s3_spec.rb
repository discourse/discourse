require 'spec_helper'
require 'fog'
require 's3'

describe S3 do

  describe "store_file" do

    let(:file) do
      ActionDispatch::Http::UploadedFile.new({
        filename: 'logo.png',
        content_type: 'image/png',
        tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
      })
    end

    let(:image_info) { FastImage.new(file) }

    before(:each) do
      SiteSetting.stubs(:s3_upload_bucket).returns("s3_upload_bucket")
      SiteSetting.stubs(:s3_access_key_id).returns("s3_access_key_id")
      SiteSetting.stubs(:s3_secret_access_key).returns("s3_secret_access_key")
      Fog.mock!
    end

    it 'returns the url of the S3 upload if successful' do
      S3.store_file(file, "SHA", 1).should == '//s3_upload_bucket.s3.amazonaws.com/1SHA.png'
    end

    after(:each) do
      Fog.unmock!
    end

  end

end
