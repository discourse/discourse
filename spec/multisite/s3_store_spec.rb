# frozen_string_literal: true

require "file_store/s3_store"

RSpec.describe "Multisite s3 uploads", type: :multisite do
  let(:original_filename) { "smallest.png" }
  let(:uploaded_file) { file_from_fixtures(original_filename) }
  let(:upload_sha1) { Digest::SHA1.hexdigest(File.read(uploaded_file)) }
  let(:upload_path) { Discourse.store.upload_path }

  def build_upload(secure: false)
    Fabricate.build(
      :upload,
      sha1: upload_sha1,
      id: 1,
      original_filename: original_filename,
      secure: secure,
    )
  end

  describe "uploading to s3" do
    before(:each) { setup_s3 }

    describe "#store_upload" do
      let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
      let(:s3_helper) { S3Helper.new(SiteSetting.s3_upload_bucket, "", client: s3_client) }
      let(:store) { FileStore::S3Store.new(s3_helper) }
      let(:upload_opts) do
        {
          acl: "public-read",
          cache_control: "max-age=31556952, public, immutable",
          content_type: "image/png",
        }
      end

      context "when the file is a SVG" do
        let(:original_filename) { "small.svg" }
        let(:uploaded_file) { file_from_fixtures("small.svg", "svg") }

        it "adds an attachment content-disposition with the original filename" do
          disp_opts = {
            content_disposition:
              "attachment; filename=\"#{original_filename}\"; filename*=UTF-8''#{original_filename}",
            content_type: "image/svg+xml",
          }
          s3_helper
            .expects(:upload)
            .with(uploaded_file, kind_of(String), upload_opts.merge(disp_opts))
            .returns(%w[path etag])
          upload = build_upload
          store.store_upload(uploaded_file, upload)
        end
      end

      context "when the file is a video" do
        let(:original_filename) { "small.mp4" }
        let(:uploaded_file) { file_from_fixtures("small.mp4", "media") }

        it "adds inline content-disposition header with original filename" do
          disp_opts = {
            content_disposition:
              "inline; filename=\"#{original_filename}\"; filename*=UTF-8''#{original_filename}",
            content_type: "application/mp4",
          }
          s3_helper
            .expects(:upload)
            .with(uploaded_file, kind_of(String), upload_opts.merge(disp_opts))
            .returns(%w[path etag])
          upload = build_upload
          store.store_upload(uploaded_file, upload)
        end
      end

      context "when the file is audio" do
        let(:original_filename) { "small.mp3" }
        let(:uploaded_file) { file_from_fixtures("small.mp3", "media") }

        it "adds inline content-disposition header with filename" do
          disp_opts = {
            content_disposition:
              "inline; filename=\"#{original_filename}\"; filename*=UTF-8''#{original_filename}",
            content_type: "audio/mpeg",
          }
          s3_helper
            .expects(:upload)
            .with(uploaded_file, kind_of(String), upload_opts.merge(disp_opts))
            .returns(%w[path etag])
          upload = build_upload
          store.store_upload(uploaded_file, upload)
        end
      end

      it "returns the correct url for default and second multisite db" do
        test_multisite_connection("default") do
          upload = build_upload
          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-west-1.amazonaws.com/#{upload_path}/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png",
          )
          expect(upload.etag).to eq("ETag")
        end

        test_multisite_connection("second") do
          upload_path = Discourse.store.upload_path
          upload = build_upload
          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-west-1.amazonaws.com/#{upload_path}/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png",
          )
          expect(upload.etag).to eq("ETag")
        end
      end
    end
  end

  describe "removal from s3" do
    before { setup_s3 }

    describe "#remove_upload" do
      let(:store) { FileStore::S3Store.new }

      let(:upload) { build_upload }
      let(:upload_key) { "#{upload_path}/original/1X/#{upload.sha1}.png" }

      def prepare_fake_s3
        @fake_s3 = FakeS3.create
        bucket = @fake_s3.bucket(SiteSetting.s3_upload_bucket)
        bucket.put_object(key: upload_key, size: upload.filesize, last_modified: upload.created_at)
        bucket
      end

      it "removes the file from s3 on multisite" do
        test_multisite_connection("default") do
          upload.update!(
            url:
              "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{upload_path}/original/1X/#{upload.sha1}.png",
          )
          tombstone_key = "uploads/tombstone/default/original/1X/#{upload.sha1}.png"
          bucket = prepare_fake_s3

          expect(bucket.find_object(upload_key)).to be_present
          expect(bucket.find_object(tombstone_key)).to be_nil

          store.remove_upload(upload)

          expect(bucket.find_object(upload_key)).to be_nil
          expect(bucket.find_object(tombstone_key)).to be_present
        end
      end

      it "removes the file from s3 on another multisite db" do
        test_multisite_connection("second") do
          upload.update!(
            url:
              "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{upload_path}/original/1X/#{upload.sha1}.png",
          )
          tombstone_key = "uploads/tombstone/second/original/1X/#{upload.sha1}.png"
          bucket = prepare_fake_s3

          expect(bucket.find_object(upload_key)).to be_present
          expect(bucket.find_object(tombstone_key)).to be_nil

          store.remove_upload(upload)

          expect(bucket.find_object(upload_key)).to be_nil
          expect(bucket.find_object(tombstone_key)).to be_present
        end
      end

      describe "when s3_upload_bucket includes folders path" do
        let(:upload_key) { "discourse-uploads/#{upload_path}/original/1X/#{upload.sha1}.png" }

        before { SiteSetting.s3_upload_bucket = "s3-upload-bucket/discourse-uploads" }

        it "removes the file from s3 on multisite" do
          test_multisite_connection("default") do
            upload.update!(
              url:
                "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/discourse-uploads/#{upload_path}/original/1X/#{upload.sha1}.png",
            )
            tombstone_key =
              "discourse-uploads/uploads/tombstone/default/original/1X/#{upload.sha1}.png"
            bucket = prepare_fake_s3

            expect(bucket.find_object(upload_key)).to be_present
            expect(bucket.find_object(tombstone_key)).to be_nil

            store.remove_upload(upload)

            expect(bucket.find_object(upload_key)).to be_nil
            expect(bucket.find_object(tombstone_key)).to be_present
          end
        end
      end
    end
  end

  describe "secure uploads" do
    let(:store) { FileStore::S3Store.new }
    let(:client) { Aws::S3::Client.new(stub_responses: true) }
    let(:resource) { Aws::S3::Resource.new(client: client) }
    let(:s3_bucket) { resource.bucket("some-really-cool-bucket") }
    let(:s3_helper) { store.s3_helper }
    let(:s3_object) { stub }

    before(:each) do
      setup_s3
      SiteSetting.s3_upload_bucket = "some-really-cool-bucket"
      SiteSetting.authorized_extensions = "pdf|png|jpg|gif"
    end

    before { s3_object.stubs(:put).returns(Aws::S3::Types::PutObjectOutput.new(etag: "etag")) }

    describe "when secure attachments are enabled" do
      it "returns signed URL with correct path" do
        test_multisite_connection("default") do
          upload =
            Fabricate(:upload, original_filename: "small.pdf", extension: "pdf", secure: true)
          path = Discourse.store.get_path_for_upload(upload)

          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          s3_bucket.expects(:object).with("#{upload_path}/#{path}").returns(s3_object).at_least_once
          s3_object.expects(:presigned_url).with(
            :get,
            { expires_in: SiteSetting.s3_presigned_get_url_expires_after_seconds },
          )

          upload.url = store.store_upload(uploaded_file, upload)
          expect(upload.url).to eq(
            "//some-really-cool-bucket.s3.dualstack.us-west-1.amazonaws.com/#{upload_path}/#{path}",
          )
          expect(store.url_for(upload)).not_to eq(upload.url)
        end
      end
    end

    describe "when secure uploads are enabled" do
      before do
        SiteSetting.login_required = true
        SiteSetting.secure_uploads = true
        s3_helper.stubs(:s3_client).returns(client)
        Discourse.stubs(:store).returns(store)
      end

      it "returns signed URL with correct path" do
        test_multisite_connection("default") do
          upload = Fabricate.build(:upload_s3, sha1: upload_sha1, id: 1)

          signed_url = Discourse.store.signed_url_for_path(upload.url)
          expect(signed_url).to match(/Amz-Expires/)
          expect(signed_url).to match("#{upload_path}")
        end

        test_multisite_connection("second") do
          upload_path = Discourse.store.upload_path
          upload = Fabricate.build(:upload_s3, sha1: upload_sha1, id: 1)

          signed_url = Discourse.store.signed_url_for_path(upload.url)
          expect(signed_url).to match(/Amz-Expires/)
          expect(signed_url).to match("#{upload_path}")
        end
      end
    end

    describe "#update_upload_ACL" do
      it "updates correct file for default and second multisite db" do
        test_multisite_connection("default") do
          upload = build_upload(secure: true)
          upload.update!(original_filename: "small.pdf", extension: "pdf")

          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          expect_upload_acl_update(upload, upload_path)

          expect(store.update_upload_ACL(upload)).to be_truthy
        end

        test_multisite_connection("second") do
          upload_path = Discourse.store.upload_path
          upload = build_upload(secure: true)
          upload.update!(original_filename: "small.pdf", extension: "pdf")

          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          expect_upload_acl_update(upload, upload_path)

          expect(store.update_upload_ACL(upload)).to be_truthy
        end
      end

      describe "optimized images" do
        it "updates correct file for default and second multisite DB" do
          test_multisite_connection("default") do
            upload = build_upload(secure: true)
            upload_path = Discourse.store.upload_path
            optimized_image = Fabricate(:optimized_image, upload: upload)
            s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
            expect_upload_acl_update(upload, upload_path)
            expect_optimized_image_acl_update(optimized_image, upload_path)

            expect(store.update_upload_ACL(upload)).to be_truthy
          end

          test_multisite_connection("second") do
            upload = build_upload(secure: true)
            upload_path = Discourse.store.upload_path
            optimized_image = Fabricate(:optimized_image, upload: upload)
            s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
            expect_upload_acl_update(upload, upload_path)
            expect_optimized_image_acl_update(optimized_image, upload_path)

            expect(store.update_upload_ACL(upload)).to be_truthy
          end
        end
      end

      def expect_upload_acl_update(upload, upload_path)
        s3_bucket
          .expects(:object)
          .with("#{upload_path}/original/1X/#{upload.sha1}.#{upload.extension}")
          .returns(s3_object)
        s3_object.expects(:acl).returns(s3_object)
        s3_object.expects(:put).with(acl: "private").returns(s3_object)
      end

      def expect_optimized_image_acl_update(optimized_image, upload_path)
        path = Discourse.store.get_path_for_optimized_image(optimized_image)
        s3_bucket.expects(:object).with("#{upload_path}/#{path}").returns(s3_object)
        s3_object.expects(:acl).returns(s3_object)
        s3_object.expects(:put).with(acl: "private").returns(s3_object)
      end
    end
  end

  describe "#has_been_uploaded?" do
    before do
      setup_s3
      SiteSetting.s3_upload_bucket = "s3-upload-bucket/test"
    end

    let(:store) { FileStore::S3Store.new }

    it "returns false for blank urls and bad urls" do
      expect(store.has_been_uploaded?("")).to eq(false)
      expect(store.has_been_uploaded?("http://test@test.com:test/test.git")).to eq(false)
      expect(store.has_been_uploaded?("http:///+test@test.com/test.git")).to eq(false)
    end

    it "returns true if the base hostname is the same for both urls" do
      url =
        "https://s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/test/original/2X/d/dd7964f5fd13e1103c5244ca30abe1936c0a4b88.png"
      expect(store.has_been_uploaded?(url)).to eq(true)
    end

    it "returns false if the base hostname is the same for both urls BUT the bucket name is different in the path" do
      bucket = "someotherbucket"
      url =
        "https://s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{bucket}/original/2X/d/dd7964f5fd13e1103c5244ca30abe1936c0a4b88.png"
      expect(store.has_been_uploaded?(url)).to eq(false)
    end

    it "returns false if the hostnames do not match and the s3_cdn_url is blank" do
      url =
        "https://www.someotherhostname.com/test/original/2X/d/dd7964f5fd13e1103c5244ca30abe1936c0a4b88.png"
      expect(store.has_been_uploaded?(url)).to eq(false)
    end

    it "returns true if the s3_cdn_url is present and matches the url hostname" do
      SiteSetting.s3_cdn_url = "https://www.someotherhostname.com"
      url =
        "https://www.someotherhostname.com/test/original/2X/d/dd7964f5fd13e1103c5244ca30abe1936c0a4b88.png"
      expect(store.has_been_uploaded?(url)).to eq(true)
    end

    it "returns false if the URI is an invalid mailto link" do
      link = "mailto: roman;@test.com"

      expect(store.has_been_uploaded?(link)).to eq(false)
    end
  end

  describe "#signed_request_for_temporary_upload" do
    before { setup_s3 }

    let(:store) { FileStore::S3Store.new }

    context "for a bucket with no folder path" do
      before { SiteSetting.s3_upload_bucket = "s3-upload-bucket" }

      it "returns a presigned url and headers with the correct params and the key for the temporary file" do
        url, signed_headers = store.signed_request_for_temporary_upload("test.png")
        key = store.s3_helper.path_from_url(url)
        expect(signed_headers).to eq("x-amz-acl" => "private")
        expect(url).to match(/Amz-Expires/)
        expect(key).to match(
          /temp\/uploads\/default\/test_[0-9]\/[a-zA-z0-9]{0,32}\/[a-zA-z0-9]{0,32}.png/,
        )
      end

      it "presigned url headers contains the metadata when provided" do
        url, signed_headers =
          store.signed_request_for_temporary_upload(
            "test.png",
            metadata: {
              "test-meta": "testing",
            },
          )
        expect(signed_headers).to eq("x-amz-acl" => "private", "x-amz-meta-test-meta" => "testing")
        expect(url).not_to include("&x-amz-meta-test-meta=testing")
      end
    end

    context "for a bucket with a folder path" do
      before { SiteSetting.s3_upload_bucket = "s3-upload-bucket/site" }

      it "returns a presigned url with the correct params and the key for the temporary file" do
        url, _signed_headers = store.signed_request_for_temporary_upload("test.png")
        key = store.s3_helper.path_from_url(url)
        expect(url).to match(/Amz-Expires/)
        expect(key).to match(
          /temp\/site\/uploads\/default\/test_[0-9]\/[a-zA-z0-9]{0,32}\/[a-zA-z0-9]{0,32}.png/,
        )
      end
    end

    context "for a multisite site" do
      before { SiteSetting.s3_upload_bucket = "s3-upload-bucket/standard99" }

      it "returns a presigned url with the correct params and the key for the temporary file" do
        test_multisite_connection("second") do
          url, _signed_headers = store.signed_request_for_temporary_upload("test.png")
          key = store.s3_helper.path_from_url(url)
          expect(url).to match(/Amz-Expires/)
          expect(key).to match(
            /temp\/standard99\/uploads\/second\/test_[0-9]\/[a-zA-z0-9]{0,32}\/[a-zA-z0-9]{0,32}.png/,
          )
        end
      end
    end
  end
end
