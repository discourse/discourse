require 'rails_helper'
require 'global_path'

class GlobalPathInstance
  extend GlobalPath
end

describe GlobalPath do

  context 'cdn_relative_path' do
    def cdn_relative_path(p)
      GlobalPathInstance.cdn_relative_path(p)
    end

    it "just returns path for no cdn" do
      expect(cdn_relative_path("/test")).to eq("/test")
    end

    it "returns path when a cdn is defined with a path" do
      GlobalSetting.expects(:cdn_url).returns("//something.com/foo")
      expect(cdn_relative_path("/test")).to eq("/foo/test")
    end

    it "returns path when a cdn is defined with a path" do
      GlobalSetting.expects(:cdn_url).returns("https://something.com:221/foo")
      expect(cdn_relative_path("/test")).to eq("/foo/test")
    end
  end

  describe '#upload_cdn_path' do
    it 'generates correctly when S3 bucket has a folder' do
      global_setting :s3_access_key_id, 's3_access_key_id'
      global_setting :s3_secret_access_key, 's3_secret_access_key'
      global_setting :s3_bucket, 'file-uploads/folder'
      global_setting :s3_region, 'us-west-2'
      global_setting :s3_cdn_url, 'https://cdn-aws.com/folder'

      expect(GlobalPathInstance.upload_cdn_path("#{Discourse.store.absolute_base_url}/folder/upload.jpg"))
        .to eq("https://cdn-aws.com/folder/upload.jpg")
    end
  end
end
