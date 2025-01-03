# frozen_string_literal: true

require "file_store/s3_store"
require "file_store/local_store"

RSpec.describe FileStore::S3Store do
  let(:store) { FileStore::S3Store.new }
  let(:s3_helper) { store.s3_helper }
  let(:client) { Aws::S3::Client.new(stub_responses: true) }
  let(:resource) { Aws::S3::Resource.new(client: client) }
  let(:s3_bucket) { resource.bucket("s3-upload-bucket") }
  let(:s3_object) { stub }
  let(:upload_path) { Discourse.store.upload_path }

  fab!(:optimized_image)
  let(:optimized_image_file) { file_from_fixtures("logo.png") }
  let(:uploaded_file) { file_from_fixtures("logo.png") }
  fab!(:upload) { Fabricate(:upload, sha1: Digest::SHA1.hexdigest("secret image string")) }

  before do
    setup_s3
    SiteSetting.s3_region = "us-west-1"
  end

  describe "uploading to s3" do
    let(:etag) { "etag" }

    describe "#store_upload" do
      it "returns an absolute schemaless url" do
        s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
        s3_bucket
          .expects(:object)
          .with(regexp_matches(%r{original/\d+X.*/#{upload.sha1}\.png}))
          .returns(s3_object)
        s3_object
          .expects(:put)
          .with(
            {
              acl: "public-read",
              cache_control: "max-age=31556952, public, immutable",
              content_type: "image/png",
              body: uploaded_file,
            },
          )
          .returns(Aws::S3::Types::PutObjectOutput.new(etag: "\"#{etag}\""))

        expect(store.store_upload(uploaded_file, upload)).to match(
          %r{//s3-upload-bucket\.s3\.dualstack\.us-west-1\.amazonaws\.com/original/\d+X.*/#{upload.sha1}\.png},
        )
        expect(upload.etag).to eq(etag)
      end

      describe "when s3_upload_bucket includes folders path" do
        before do
          s3_object.stubs(:put).returns(Aws::S3::Types::PutObjectOutput.new(etag: "\"#{etag}\""))
          SiteSetting.s3_upload_bucket = "s3-upload-bucket/discourse-uploads"
        end

        it "returns an absolute schemaless url" do
          s3_helper.expects(:s3_bucket).returns(s3_bucket)

          s3_bucket
            .expects(:object)
            .with(regexp_matches(%r{discourse-uploads/original/\d+X.*/#{upload.sha1}\.png}))
            .returns(s3_object)

          expect(store.store_upload(uploaded_file, upload)).to match(
            %r{//s3-upload-bucket\.s3\.dualstack\.us-west-1\.amazonaws\.com/discourse-uploads/original/\d+X.*/#{upload.sha1}\.png},
          )
          expect(upload.etag).to eq(etag)
        end
      end

      describe "when secure uploads are enabled" do
        it "saves secure attachment using private ACL" do
          SiteSetting.prevent_anons_from_downloading_files = true
          SiteSetting.authorized_extensions = "pdf|png|jpg|gif"
          upload =
            Fabricate(:upload, original_filename: "small.pdf", extension: "pdf", secure: true)

          s3_helper.expects(:s3_bucket).returns(s3_bucket)
          s3_bucket
            .expects(:object)
            .with(regexp_matches(%r{original/\d+X.*/#{upload.sha1}\.pdf}))
            .returns(s3_object)
          s3_object
            .expects(:put)
            .with(
              {
                acl: "private",
                cache_control: "max-age=31556952, public, immutable",
                content_type: "application/pdf",
                body: uploaded_file,
              },
            )
            .returns(Aws::S3::Types::PutObjectOutput.new(etag: "\"#{etag}\""))

          expect(store.store_upload(uploaded_file, upload)).to match(
            %r{//s3-upload-bucket\.s3\.dualstack\.us-west-1\.amazonaws\.com/original/\d+X.*/#{upload.sha1}\.pdf},
          )
        end

        it "saves image upload using public ACL" do
          SiteSetting.prevent_anons_from_downloading_files = true

          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          s3_bucket
            .expects(:object)
            .with(regexp_matches(%r{original/\d+X.*/#{upload.sha1}\.png}))
            .returns(s3_object)
            .at_least_once
          s3_object
            .expects(:put)
            .with(
              {
                acl: "public-read",
                cache_control: "max-age=31556952, public, immutable",
                content_type: "image/png",
                body: uploaded_file,
              },
            )
            .returns(Aws::S3::Types::PutObjectOutput.new(etag: "\"#{etag}\""))

          expect(store.store_upload(uploaded_file, upload)).to match(
            %r{//s3-upload-bucket\.s3\.dualstack\.us-west-1\.amazonaws\.com/original/\d+X.*/#{upload.sha1}\.png},
          )

          expect(store.url_for(upload)).to eq(upload.url)
        end
      end

      describe "when ACLs are disabled" do
        it "doesn't supply an ACL" do
          SiteSetting.s3_use_acls = false
          SiteSetting.authorized_extensions = "pdf|png|jpg|gif"
          upload =
            Fabricate(:upload, original_filename: "small.pdf", extension: "pdf", secure: true)

          s3_helper.expects(:s3_bucket).returns(s3_bucket)
          s3_bucket
            .expects(:object)
            .with(regexp_matches(%r{original/\d+X.*/#{upload.sha1}\.pdf}))
            .returns(s3_object)
          s3_object
            .expects(:put)
            .with(
              {
                acl: nil,
                cache_control: "max-age=31556952, public, immutable",
                content_type: "application/pdf",
                body: uploaded_file,
              },
            )
            .returns(Aws::S3::Types::PutObjectOutput.new(etag: "\"#{etag}\""))

          expect(store.store_upload(uploaded_file, upload)).to match(
            %r{//s3-upload-bucket\.s3\.dualstack\.us-west-1\.amazonaws\.com/original/\d+X.*/#{upload.sha1}\.pdf},
          )
        end
      end
    end

    describe "#store_optimized_image" do
      before do
        s3_object.stubs(:put).returns(Aws::S3::Types::PutObjectOutput.new(etag: "\"#{etag}\""))
      end

      it "returns an absolute schemaless url" do
        s3_helper.expects(:s3_bucket).returns(s3_bucket)
        path =
          %r{optimized/\d+X.*/#{optimized_image.upload.sha1}_#{OptimizedImage::VERSION}_100x200\.png}

        s3_bucket.expects(:object).with(regexp_matches(path)).returns(s3_object)

        expect(store.store_optimized_image(optimized_image_file, optimized_image)).to match(
          %r{//s3-upload-bucket\.s3\.dualstack\.us-west-1\.amazonaws\.com/#{path}},
        )
        expect(optimized_image.etag).to eq(etag)
      end

      describe "when s3_upload_bucket includes folders path" do
        before { SiteSetting.s3_upload_bucket = "s3-upload-bucket/discourse-uploads" }

        it "returns an absolute schemaless url" do
          s3_helper.expects(:s3_bucket).returns(s3_bucket)
          path =
            %r{discourse-uploads/optimized/\d+X.*/#{optimized_image.upload.sha1}_#{OptimizedImage::VERSION}_100x200\.png}

          s3_bucket.expects(:object).with(regexp_matches(path)).returns(s3_object)

          expect(store.store_optimized_image(optimized_image_file, optimized_image)).to match(
            %r{//s3-upload-bucket\.s3\.dualstack\.us-west-1\.amazonaws\.com/#{path}},
          )
          expect(optimized_image.etag).to eq(etag)
        end
      end
    end

    describe "#move_existing_stored_upload" do
      let(:uploaded_file) { file_from_fixtures(original_filename) }
      let(:upload_sha1) { Digest::SHA1.hexdigest(File.read(uploaded_file)) }
      let(:original_filename) { "smallest.png" }
      let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
      let(:s3_helper) { S3Helper.new(SiteSetting.s3_upload_bucket, "", client: s3_client) }
      let(:store) { FileStore::S3Store.new(s3_helper) }
      let(:upload_opts) do
        {
          acl: "public-read",
          cache_control: "max-age=31556952, public, immutable",
          content_type: "image/png",
          apply_metadata_to_destination: true,
        }
      end
      let(:external_upload_stub) { Fabricate(:image_external_upload_stub) }
      let(:existing_external_upload_key) { external_upload_stub.key }

      before { SiteSetting.authorized_extensions = "svg|png" }

      it "does not provide a content_disposition for images" do
        s3_helper
          .expects(:copy)
          .with(external_upload_stub.key, kind_of(String), options: upload_opts)
          .returns(%w[path etag])
        s3_helper.expects(:delete_object).with(external_upload_stub.key)
        upload =
          Fabricate(
            :upload,
            extension: "png",
            sha1: upload_sha1,
            original_filename: original_filename,
          )
        store.move_existing_stored_upload(
          existing_external_upload_key: external_upload_stub.key,
          upload: upload,
          content_type: "image/png",
        )
      end

      context "when the file is a SVG" do
        let(:external_upload_stub) do
          Fabricate(:attachment_external_upload_stub, original_filename: original_filename)
        end
        let(:original_filename) { "small.svg" }
        let(:uploaded_file) { file_from_fixtures("small.svg", "svg") }

        it "adds an attachment content-disposition with the original filename" do
          disp_opts = {
            content_disposition:
              "attachment; filename=\"#{original_filename}\"; filename*=UTF-8''#{original_filename}",
            content_type: "image/svg+xml",
          }
          s3_helper
            .expects(:copy)
            .with(external_upload_stub.key, kind_of(String), options: upload_opts.merge(disp_opts))
            .returns(%w[path etag])
          upload =
            Fabricate(
              :upload,
              extension: "png",
              sha1: upload_sha1,
              original_filename: original_filename,
            )
          store.move_existing_stored_upload(
            existing_external_upload_key: external_upload_stub.key,
            upload: upload,
            content_type: "image/svg+xml",
          )
        end
      end
    end
  end

  describe "copying files in S3" do
    describe "#copy_file" do
      it "copies the from in S3 with the right paths" do
        upload.update!(
          url:
            "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/original/1X/#{upload.sha1}.png",
        )

        source = "#{upload_path}/#{Discourse.store.get_path_for_upload(upload)}"
        destination = source.sub(".png", ".jpg")
        bucket = prepare_fake_s3(source, upload)

        expect(bucket.find_object(source)).to be_present
        expect(bucket.find_object(destination)).to be_nil

        store.copy_file(upload.url, source, destination)

        expect(bucket.find_object(source)).to be_present
        expect(bucket.find_object(destination)).to be_present
      end
    end
  end

  describe "removal from s3" do
    describe "#remove_upload" do
      it "removes the file from s3 with the right paths" do
        upload_key = Discourse.store.get_path_for_upload(upload)
        tombstone_key = "tombstone/#{upload_key}"
        bucket = prepare_fake_s3(upload_key, upload)

        upload.update!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{upload_key}")

        expect(bucket.find_object(upload_key)).to be_present
        expect(bucket.find_object(tombstone_key)).to be_nil

        store.remove_upload(upload)

        expect(bucket.find_object(upload_key)).to be_nil
        expect(bucket.find_object(tombstone_key)).to be_present
      end

      describe "when s3_upload_bucket includes folders path" do
        before { SiteSetting.s3_upload_bucket = "s3-upload-bucket/discourse-uploads" }

        it "removes the file from s3 with the right paths" do
          upload_key = "discourse-uploads/#{Discourse.store.get_path_for_upload(upload)}"
          tombstone_key =
            "discourse-uploads/tombstone/#{Discourse.store.get_path_for_upload(upload)}"
          bucket = prepare_fake_s3(upload_key, upload)

          upload.update!(
            url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{upload_key}",
          )

          expect(bucket.find_object(upload_key)).to be_present
          expect(bucket.find_object(tombstone_key)).to be_nil

          store.remove_upload(upload)

          expect(bucket.find_object(upload_key)).to be_nil
          expect(bucket.find_object(tombstone_key)).to be_present
        end
      end
    end

    describe "#remove_optimized_image" do
      let(:optimized_key) { FileStore::BaseStore.new.get_path_for_optimized_image(optimized_image) }
      let(:tombstone_key) { "tombstone/#{optimized_key}" }
      let(:upload) { optimized_image.upload }
      let(:upload_key) { Discourse.store.get_path_for_upload(upload) }

      before do
        optimized_image.update!(
          url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{optimized_key}",
        )
        upload.update!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{upload_key}")
      end

      it "removes the optimized image from s3 with the right paths" do
        bucket = prepare_fake_s3(upload_key, upload)
        store_fake_s3_object(optimized_key, optimized_image)

        expect(bucket.find_object(upload_key)).to be_present
        expect(bucket.find_object(optimized_key)).to be_present
        expect(bucket.find_object(tombstone_key)).to be_nil

        store.remove_optimized_image(optimized_image)

        expect(bucket.find_object(upload_key)).to be_present
        expect(bucket.find_object(optimized_key)).to be_nil
        expect(bucket.find_object(tombstone_key)).to be_present
      end

      describe "when s3_upload_bucket includes folders path" do
        before { SiteSetting.s3_upload_bucket = "s3-upload-bucket/discourse-uploads" }

        let(:image_path) { FileStore::BaseStore.new.get_path_for_optimized_image(optimized_image) }
        let(:optimized_key) { "discourse-uploads/#{image_path}" }
        let(:tombstone_key) { "discourse-uploads/tombstone/#{image_path}" }
        let(:upload_key) { "discourse-uploads/#{Discourse.store.get_path_for_upload(upload)}" }

        it "removes the file from s3 with the right paths" do
          bucket = prepare_fake_s3(upload_key, upload)
          store_fake_s3_object(optimized_key, optimized_image)

          expect(bucket.find_object(upload_key)).to be_present
          expect(bucket.find_object(optimized_key)).to be_present
          expect(bucket.find_object(tombstone_key)).to be_nil

          store.remove_optimized_image(optimized_image)

          expect(bucket.find_object(upload_key)).to be_present
          expect(bucket.find_object(optimized_key)).to be_nil
          expect(bucket.find_object(tombstone_key)).to be_present
        end
      end
    end
  end

  describe ".has_been_uploaded?" do
    it "doesn't crash for invalid URLs" do
      expect(store.has_been_uploaded?("https://site.discourse.com/#bad#6")).to eq(false)
    end

    it "doesn't crash if URL contains non-ascii characters" do
      expect(
        store.has_been_uploaded?(
          "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/漢1337.png",
        ),
      ).to eq(true)
      expect(store.has_been_uploaded?("//s3-upload-bucket.s3.amazonaws.com/漢1337.png")).to eq(false)
    end

    it "identifies S3 uploads" do
      expect(
        store.has_been_uploaded?(
          "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/1337.png",
        ),
      ).to eq(true)
    end

    it "does not match other s3 urls" do
      expect(store.has_been_uploaded?("//s3-upload-bucket.s3.amazonaws.com/1337.png")).to eq(false)
      expect(
        store.has_been_uploaded?("//s3-upload-bucket.s3-us-west-1.amazonaws.com/1337.png"),
      ).to eq(false)
      expect(store.has_been_uploaded?("//s3.amazonaws.com/s3-upload-bucket/1337.png")).to eq(false)
      expect(store.has_been_uploaded?("//s4_upload_bucket.s3.amazonaws.com/1337.png")).to eq(false)
    end
  end

  describe ".absolute_base_url" do
    it "returns a lowercase schemaless absolute url" do
      expect(store.absolute_base_url).to eq(
        "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com",
      )
    end

    it "uses the proper endpoint" do
      SiteSetting.s3_region = "us-east-1"
      expect(FileStore::S3Store.new(s3_helper).absolute_base_url).to eq(
        "//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com",
      )

      SiteSetting.s3_region = "us-west-2"
      expect(FileStore::S3Store.new(s3_helper).absolute_base_url).to eq(
        "//s3-upload-bucket.s3.dualstack.us-west-2.amazonaws.com",
      )

      SiteSetting.s3_region = "cn-north-1"
      expect(FileStore::S3Store.new(s3_helper).absolute_base_url).to eq(
        "//s3-upload-bucket.s3.cn-north-1.amazonaws.com.cn",
      )

      SiteSetting.s3_region = "cn-northwest-1"
      expect(FileStore::S3Store.new(s3_helper).absolute_base_url).to eq(
        "//s3-upload-bucket.s3.cn-northwest-1.amazonaws.com.cn",
      )
    end
  end

  it "is external" do
    expect(store.external?).to eq(true)
    expect(store.internal?).to eq(false)
  end

  describe ".purge_tombstone" do
    it "updates tombstone lifecycle" do
      s3_helper.expects(:update_tombstone_lifecycle)
      store.purge_tombstone(1.day)
    end
  end

  describe ".path_for" do
    def assert_path(path, expected)
      upload = Upload.new(url: path)

      path = store.path_for(upload)
      expected = FileStore::LocalStore.new.path_for(upload) if expected

      expect(path).to eq(expected)
    end

    it "correctly falls back to local" do
      assert_path("/hello", "/hello")
      assert_path("//hello", nil)
      assert_path("http://hello", nil)
      assert_path("https://hello", nil)
    end
  end

  describe "update ACL" do
    before { SiteSetting.authorized_extensions = "pdf|png" }

    describe ".update_upload_ACL" do
      let(:upload) { Fabricate(:upload, original_filename: "small.pdf", extension: "pdf") }

      it "sets acl to public by default" do
        s3_helper.expects(:s3_bucket).returns(s3_bucket)
        expect_upload_acl_update(upload, "public-read")

        expect(store.update_upload_ACL(upload)).to be_truthy
      end

      it "sets acl to private when upload is marked secure" do
        upload.update!(secure: true)
        s3_helper.expects(:s3_bucket).returns(s3_bucket)
        expect_upload_acl_update(upload, "private")

        expect(store.update_upload_ACL(upload)).to be_truthy
      end

      describe "optimized images" do
        it "sets acl to public by default" do
          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          expect_upload_acl_update(upload, "public-read")
          optimized_image = Fabricate(:optimized_image, upload: upload)
          path = Discourse.store.get_path_for_optimized_image(optimized_image)

          stub_optimized_image = stub
          s3_bucket.expects(:object).with(path).returns(stub_optimized_image)
          stub_optimized_image.expects(:acl).returns(stub_optimized_image)
          stub_optimized_image.expects(:put).with(acl: "public-read").returns(stub_optimized_image)

          expect(store.update_upload_ACL(upload)).to be_truthy
        end
      end

      def expect_upload_acl_update(upload, acl)
        s3_bucket
          .expects(:object)
          .with(regexp_matches(%r{original/\d+X.*/#{upload.sha1}\.pdf}))
          .returns(s3_object)
        s3_object.expects(:acl).returns(s3_object)
        s3_object.expects(:put).with(acl: acl).returns(s3_object)
      end
    end
  end

  describe ".cdn_url" do
    it "supports subfolder" do
      SiteSetting.s3_upload_bucket = "s3-upload-bucket/livechat"
      SiteSetting.s3_cdn_url = "https://rainbow.com"

      # none of this should matter at all
      # subfolder should not leak into uploads
      set_subfolder "/community"

      url = "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/livechat/original/gif.png"

      expect(store.cdn_url(url)).to eq("https://rainbow.com/original/gif.png")
    end
  end

  describe ".download_url" do
    it "returns correct short URL with dl=1 param" do
      expect(store.download_url(upload)).to eq("#{upload.short_path}?dl=1")
    end
  end

  describe ".url_for" do
    it "returns signed URL with content disposition when requesting to download image" do
      s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
      s3_bucket
        .expects(:object)
        .with(regexp_matches(%r{original/\d+X.*/#{upload.sha1}\.png}))
        .returns(s3_object)
      opts = {
        expires_in: SiteSetting.s3_presigned_get_url_expires_after_seconds,
        response_content_disposition:
          %Q|attachment; filename="#{upload.original_filename}"; filename*=UTF-8''#{upload.original_filename}|,
      }

      s3_object.expects(:presigned_url).with(:get, opts)

      expect(store.url_for(upload, force_download: true)).not_to eq(upload.url)
    end
  end

  describe ".signed_url_for_path" do
    it "returns signed URL for a given path" do
      s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
      s3_bucket.expects(:object).with("special/optimized/file.png").returns(s3_object)
      opts = { expires_in: SiteSetting.s3_presigned_get_url_expires_after_seconds }

      s3_object.expects(:presigned_url).with(:get, opts)

      expect(store.signed_url_for_path("special/optimized/file.png")).not_to eq(upload.url)
    end

    it "does not prefix the s3_bucket_folder_path onto temporary upload prefixed keys" do
      SiteSetting.s3_upload_bucket = "s3-upload-bucket/folder_path"
      uri =
        URI.parse(
          store.signed_url_for_path(
            "#{FileStore::BaseStore::TEMPORARY_UPLOAD_PREFIX}folder_path/uploads/default/blah/def.xyz",
          ),
        )
      expect(uri.path).to eq(
        "/#{FileStore::BaseStore::TEMPORARY_UPLOAD_PREFIX}folder_path/uploads/default/blah/def.xyz",
      )
      uri = URI.parse(store.signed_url_for_path("uploads/default/blah/def.xyz"))
      expect(uri.path).to eq("/folder_path/uploads/default/blah/def.xyz")
    end
  end

  def prepare_fake_s3(upload_key, upload)
    @fake_s3 = FakeS3.create
    @fake_s3_bucket = @fake_s3.bucket(SiteSetting.s3_upload_bucket)
    store_fake_s3_object(upload_key, upload)
    @fake_s3_bucket
  end

  def store_fake_s3_object(upload_key, upload)
    @fake_s3_bucket.put_object(
      key: upload_key,
      size: upload.filesize,
      last_modified: upload.created_at,
    )
  end
end
