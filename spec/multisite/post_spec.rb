# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Multisite Post', type: :multisite do
  describe '#each_upload_url' do
    let(:upload1) { Fabricate(:upload_s3) }
    let(:upload2) { Fabricate(:upload_s3) }
    let(:upload3) { Fabricate(:upload_s3) }

    it "correctly identifies all upload urls" do
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_upload_bucket = "s3-upload-bucket"
      SiteSetting.s3_access_key_id = "some key"
      SiteSetting.s3_secret_access_key = "some secret key"
      SiteSetting.s3_cdn_url = "https://cdn.s3.amazonaws.com"

      upload3.url.sub!(RailsMultisite::ConnectionManagement.current_db, "secondsite")
      upload3.save!

      urls = []
      post = Fabricate(:post, raw: "A post with image and link upload.\n\n![](#{upload1.short_path})\n\n<a href='#{upload2.url}'>Link to upload</a>\n![](#{upload3.url})")
      post.each_upload_url { |src, _, _| urls << src.sub("http:", "") }
      expect(urls).to eq([upload1.short_path, upload2.url])
    end
  end
end
