# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileStore::BaseStore do
  fab!(:upload) { Fabricate(:upload, id: 9999, sha1: Digest::SHA1.hexdigest('9999')) }

  describe '#get_path_for_upload' do
    it 'should return the right path' do
      expect(FileStore::BaseStore.new.get_path_for_upload(upload))
        .to eq('original/2X/4/4170ac2a2782a1516fe9e13d7322ae482c1bd594.png')
    end

    describe 'when Upload#extension has not been set' do
      it 'should return the right path' do
        upload.update!(extension: nil)

        expect(FileStore::BaseStore.new.get_path_for_upload(upload))
          .to eq('original/2X/4/4170ac2a2782a1516fe9e13d7322ae482c1bd594.png')
      end
    end

    describe 'when id is negative' do
      it 'should return the right depth' do
        upload.update!(id: -999)

        expect(FileStore::BaseStore.new.get_path_for_upload(upload))
          .to eq('original/1X/4170ac2a2782a1516fe9e13d7322ae482c1bd594.png')
      end
    end
  end

  describe '#get_path_for_optimized_image' do
    let(:upload) { Fabricate.build(:upload, id: 100) }
    let(:optimized_path) { "optimized/1X/#{upload.sha1}_1_100x200.png" }

    it 'should return the right path' do
      optimized = Fabricate.build(:optimized_image, upload: upload, version: 1)
      expect(FileStore::BaseStore.new.get_path_for_optimized_image(optimized)).to eq(optimized_path)
    end

    it 'should return the right path for `nil` version' do
      optimized = Fabricate.build(:optimized_image, upload: upload, version: nil)
      expect(FileStore::BaseStore.new.get_path_for_optimized_image(optimized)).to eq(optimized_path)
    end
  end

  describe '#download' do
    before do
      `rm -rf #{FileStore::BaseStore::CACHE_DIR}`

      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_upload_bucket = "s3-upload-bucket"
      SiteSetting.s3_access_key_id = "some key"
      SiteSetting.s3_secret_access_key = "some secret key"
      SiteSetting.s3_region = "us-east-1"

      stub_request(:get, upload_s3.url).to_return(status: 200, body: "Hello world")
    end

    let(:upload_s3) { Fabricate(:upload_s3) }
    let(:store) { FileStore::BaseStore.new }

    it "should return consistent encodings for fresh and cached downloads" do
      # Net::HTTP always returns binary ASCII-8BIT encoding. File.read auto-detects the encoding
      # Make sure we File.read after downloading a file for consistency

      first_encoding = store.download(upload_s3).read.encoding

      second_encoding = store.download(upload_s3).read.encoding

      expect(first_encoding).to eq(Encoding::UTF_8)
      expect(second_encoding).to eq(Encoding::UTF_8)
    end

    it "should return the file" do
      file = store.download(upload_s3)

      expect(file.class).to eq(File)
    end

    it "should return the file when s3 cdn enabled" do
      SiteSetting.s3_cdn_url = "https://cdn.s3.amazonaws.com"
      stub_request(:get, Discourse.store.cdn_url(upload_s3.url)).to_return(status: 200, body: "Hello world")

      file = store.download(upload_s3)

      expect(file.class).to eq(File)
    end

    it "should return the file when secure media are enabled" do
      SiteSetting.login_required = true
      SiteSetting.secure_media = true

      stub_request(:head, "https://s3-upload-bucket.s3.amazonaws.com/")
      signed_url = Discourse.store.signed_url_for_path(upload_s3.url)
      stub_request(:get, signed_url).to_return(status: 200, body: "Hello world")

      file = store.download(upload_s3)

      expect(file.class).to eq(File)
    end
  end
end
