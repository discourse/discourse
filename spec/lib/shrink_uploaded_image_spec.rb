# frozen_string_literal: true

require 'rails_helper'

describe ShrinkUploadedImage do
  context "when local uploads are enabled" do
    let(:upload) { Fabricate(:image_upload, width: 200, height: 200) }

    it "resizes the image" do
      filesize_before = upload.filesize
      post = Fabricate(:post, raw: "<img src='#{upload.url}'>")
      post.link_post_uploads

      result = ShrinkUploadedImage.new(
        upload: upload,
        path: Discourse.store.path_for(upload),
        max_pixels: 10_000
      ).perform

      expect(result).to be(true)
      expect(upload.width).to eq(100)
      expect(upload.height).to eq(100)
      expect(upload.filesize).to be < filesize_before
    end

    it "returns false if the image is not used by any models" do
      result = ShrinkUploadedImage.new(
        upload: upload,
        path: Discourse.store.path_for(upload),
        max_pixels: 10_000
      ).perform

      expect(result).to be(false)
    end

    it "returns false if the image cannot be shrunk more" do
      post = Fabricate(:post, raw: "<img src='#{upload.url}'>")
      post.link_post_uploads
      ShrinkUploadedImage.new(
        upload: upload,
        path: Discourse.store.path_for(upload),
        max_pixels: 10_000
      ).perform

      upload.reload

      result = ShrinkUploadedImage.new(
        upload: upload,
        path: Discourse.store.path_for(upload),
        max_pixels: 10_000
      ).perform

      expect(result).to be(false)
    end

    it "returns false when the upload is above the size limit" do
      post = Fabricate(:post, raw: "<img src='#{upload.url}'>")
      post.link_post_uploads
      SiteSetting.max_image_size_kb = 0.001 # 1 byte

      result = ShrinkUploadedImage.new(
        upload: upload,
        path: Discourse.store.path_for(upload),
        max_pixels: 10_000
      ).perform

      expect(result).to be(false)
    end
  end

  context "when S3 uploads are enabled" do
    let(:upload) { Fabricate(:s3_image_upload, width: 200, height: 200) }

    before do
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_access_key_id = "fakeid7974664"
      SiteSetting.s3_secret_access_key = "fakesecretid7974664"

      store = FileStore::S3Store.new
      s3_helper = store.instance_variable_get(:@s3_helper)
      client = Aws::S3::Client.new(stub_responses: true)
      s3_helper.stubs(:s3_client).returns(client)
      Discourse.stubs(:store).returns(store)
    end

    it "resizes the image" do
      filesize_before = upload.filesize
      post = Fabricate(:post, raw: "<img src='#{upload.url}'>")
      post.link_post_uploads

      result = ShrinkUploadedImage.new(
        upload: upload,
        path: Discourse.store.download(upload).path,
        max_pixels: 10_000
      ).perform

      expect(result).to be(true)
      expect(upload.width).to eq(100)
      expect(upload.height).to eq(100)
      expect(upload.filesize).to be < filesize_before
    end
  end
end
