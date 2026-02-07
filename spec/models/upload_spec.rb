# frozen_string_literal: true

RSpec.describe Upload do
  let(:upload) { build(:upload) }
  let(:user_id) { 1 }

  let(:image_filename) { "logo.png" }
  let(:image) { file_from_fixtures(image_filename) }

  let(:image_svg_filename) { "image.svg" }
  let(:image_svg) { file_from_fixtures(image_svg_filename) }

  let(:huge_image_filename) { "huge.jpg" }
  let(:huge_image) { file_from_fixtures(huge_image_filename) }

  let(:attachment_path) { __FILE__ }
  let(:attachment) { File.new(attachment_path) }

  it { is_expected.to have_many(:badges).dependent(:nullify) }

  describe ".fetch_from" do
    subject(:record) { described_class.fetch_from(sha1:, url:) }

    fab!(:upload)

    let(:url) { upload.url }

    context "when sha1 is present" do
      context "when there is a matching upload for this SHA1" do
        let(:sha1) { upload.sha1 }

        it "returns the record" do
          expect(record).to eq(upload)
        end
      end

      context "when there is no matching upload for this SHA1" do
        let(:sha1) { "non-existent" }

        it "fetches the record using the provided URL" do
          expect(record).to eq(upload)
        end
      end
    end

    context "when sha1 is blank" do
      let(:sha1) { "" }

      it "fetches the record using the provided URL" do
        expect(record).to eq(upload)
      end
    end
  end

  describe ".with_no_non_post_relations" do
    it "does not find non-post related uploads" do
      post_upload = Fabricate(:upload)
      post =
        Fabricate(
          :post,
          raw: "<img src='#{post_upload.url}'>",
          user: Fabricate(:user, refresh_auto_groups: true),
        )
      post.link_post_uploads

      badge_upload = Fabricate(:upload)
      Fabricate(:badge, image_upload: badge_upload)

      avatar_upload = Fabricate(:upload)
      Fabricate(:user, uploaded_avatar: avatar_upload)

      site_setting_upload = Fabricate(:upload)
      SiteSetting.create!(
        name: "logo",
        data_type: SiteSettings::TypeSupervisor.types[:upload],
        value: site_setting_upload.id,
      )

      upload_ids = Upload.by_users.with_no_non_post_relations.pluck(:id)
      expect(upload_ids).to eq([post_upload.id])
    end
  end

  describe "video conversion" do
    let(:user) { Fabricate(:user) }

    before do
      # Add mp4 to authorized extensions for video uploads
      extensions = SiteSetting.authorized_extensions.split("|")
      SiteSetting.authorized_extensions = (extensions | ["mp4"]).join("|")

      SiteSetting.video_conversion_service = "aws_mediaconvert"
      SiteSetting.mediaconvert_role_arn = "arn:aws:iam::123456789012:role/MediaConvertRole"
      SiteSetting.enable_s3_uploads = true
      SiteSetting.video_conversion_enabled = true
    end

    context "when video conversion is enabled" do
      it "enqueues a convert_video job for supported video files on create" do
        allow(FileHelper).to receive(:is_supported_video?).with("small.mp4").and_return(true)

        upload = nil
        expect_enqueued_with(job: :convert_video, args: {}) do
          upload = Fabricate(:upload, original_filename: "small.mp4", extension: "mp4", user: user)
        end
        expect_job_enqueued(job: :convert_video, args: { upload_id: upload.id })
      end

      it "does not enqueue a convert_video job for unsupported video files" do
        allow(FileHelper).to receive(:is_supported_video?).with("small.mp4").and_return(false)

        expect_not_enqueued_with(job: :convert_video) do
          Fabricate(:upload, original_filename: "small.mp4", extension: "mp4", user: user)
        end
      end

      it "does not enqueue a convert_video job when video conversion is disabled" do
        SiteSetting.video_conversion_enabled = false
        allow(FileHelper).to receive(:is_supported_video?).with("small.mp4").and_return(true)

        expect_not_enqueued_with(job: :convert_video) do
          Fabricate(:upload, original_filename: "small.mp4", extension: "mp4", user: user)
        end
      end

      it "does not enqueue a convert_video job when S3 uploads are disabled" do
        SiteSetting.enable_s3_uploads = false
        allow(FileHelper).to receive(:is_supported_video?).with("small.mp4").and_return(true)

        expect_not_enqueued_with(job: :convert_video) do
          Fabricate(:upload, original_filename: "small.mp4", extension: "mp4", user: user)
        end
      end

      it "does not enqueue a convert_video job for non-video files" do
        expect_not_enqueued_with(job: :convert_video) do
          Fabricate(:upload, original_filename: "image.png", extension: "png", user: user)
        end
      end

      it "does not enqueue a convert_video job if OptimizedVideo already exists" do
        allow(FileHelper).to receive(:is_supported_video?).with("small.mp4").and_return(true)
        allow(FileHelper).to receive(:is_supported_video?).with("video_converted.mp4").and_return(
          true,
        )

        # Create original upload
        upload = Fabricate(:upload, original_filename: "small.mp4", extension: "mp4", user: user)

        # Create OptimizedVideo record for the original upload
        optimized_video = Fabricate(:optimized_video, upload: upload)

        # Update the original upload to trigger after_commit
        expect_not_enqueued_with(job: :convert_video) { upload.update!(filesize: 12_345) }
      end

      it "does not enqueue a convert_video job on update, only on create" do
        allow(FileHelper).to receive(:is_supported_video?).with("small.mp4").and_return(true)

        upload = Fabricate(:upload, original_filename: "small.mp4", extension: "mp4", user: user)

        # Update the upload - should not trigger video conversion since it's after_create, not after_update
        expect_not_enqueued_with(job: :convert_video) { upload.update!(filesize: 12_345) }
      end

      it "does not enqueue a convert_video job for optimized video uploads to prevent infinite loop" do
        allow(FileHelper).to receive(:is_supported_video?).with("small.mp4").and_return(true)
        allow(FileHelper).to receive(:is_supported_video?).with("video_converted.mp4").and_return(
          true,
        )

        # Create original upload
        upload = Fabricate(:upload, original_filename: "small.mp4", extension: "mp4", user: user)

        # Use OptimizedVideo.create_for to simulate the real flow
        # This creates the optimized upload and then the OptimizedVideo record
        optimized_video = nil
        optimized_upload = nil
        expect_not_enqueued_with(job: :convert_video) do
          optimized_video =
            OptimizedVideo.create_for(
              upload,
              "video_converted.mp4",
              user.id,
              filesize: 1000,
              sha1: "abcdef1234567890",
              url: "https://example.com/video_converted.mp4",
              adapter: "aws_mediaconvert",
            )
        end

        expect(optimized_video).not_to be_nil
      end

      it "enqueues a convert_video job for user uploads with _converted in filename" do
        allow(FileHelper).to receive(:is_supported_video?).with(
          "my_video_converted.mp4",
        ).and_return(true)

        # User uploads a file with "_converted" in the name - should still be converted
        upload = nil
        expect_enqueued_with(job: :convert_video, args: {}) do
          upload =
            Fabricate(
              :upload,
              original_filename: "my_video_converted.mp4",
              extension: "mp4",
              user: user,
            )
        end
        expect_job_enqueued(job: :convert_video, args: { upload_id: upload.id })
      end
    end
  end

  describe ".create_thumbnail!" do
    it "does not create a thumbnail when disabled" do
      SiteSetting.create_thumbnails = false
      OptimizedImage.expects(:create_for).never
      upload.create_thumbnail!(100, 100)
    end

    it "creates a thumbnail" do
      upload = Fabricate(:upload)
      thumbnail = Fabricate(:optimized_image, upload: upload)
      SiteSetting.expects(:create_thumbnails?).returns(true)
      OptimizedImage.expects(:create_for).returns(thumbnail)
      upload.create_thumbnail!(100, 100)
      upload.reload
      expect(upload.optimized_images.count).to eq(1)
    end
  end

  it "supports <style> element in SVG" do
    SiteSetting.authorized_extensions = "svg"

    upload = UploadCreator.new(image_svg, image_svg_filename).create_for(user_id)
    expect(upload.valid?).to eq(true)

    path = Discourse.store.path_for(upload)
    expect(File.read(path)).to match(/<style>/)
  end

  it "can reconstruct dimensions on demand" do
    SiteSetting.max_image_megapixels = 85
    upload = UploadCreator.new(huge_image, "image.png").create_for(user_id)

    upload.update_columns(width: nil, height: nil, thumbnail_width: nil, thumbnail_height: nil)

    upload = Upload.find(upload.id)

    expect(upload.width).to eq(8900)
    expect(upload.height).to eq(8900)

    upload.reload
    expect(upload.read_attribute(:width)).to eq(8900)

    upload.update_columns(width: nil, height: nil, thumbnail_width: nil, thumbnail_height: nil)

    expect(upload.thumbnail_width).to eq(500)
    expect(upload.thumbnail_height).to eq(500)
  end

  it "dimension calculation returns nil on missing image" do
    SiteSetting.max_image_megapixels = 85
    upload = UploadCreator.new(huge_image, "image.png").create_for(user_id)
    upload.update_columns(width: nil, height: nil, thumbnail_width: nil, thumbnail_height: nil)

    missing_url = "wrong_folder#{upload.url}"
    upload.update_columns(url: missing_url)
    expect(upload.thumbnail_height).to eq(nil)
    expect(upload.thumbnail_width).to eq(nil)
  end

  it "returns error when image resolution is to big" do
    SiteSetting.max_image_megapixels = 10
    upload = UploadCreator.new(huge_image, "image.png").create_for(user_id)
    expect(upload.persisted?).to eq(false)
    expect(upload.errors.messages[:base].first).to eq(
      I18n.t(
        "upload.images.larger_than_x_megapixels",
        max_image_megapixels: 10,
        original_filename: upload.original_filename,
      ),
    )
  end

  it "extracts file extension" do
    created_upload = UploadCreator.new(image, image_filename).create_for(user_id)
    expect(created_upload.extension).to eq("png")
  end

  it "should create an invalid upload when the filename is blank" do
    SiteSetting.authorized_extensions = "*"
    created_upload = UploadCreator.new(attachment, nil).create_for(user_id)
    expect(created_upload.valid?).to eq(false)
  end

  describe ".extract_url" do
    let(:url) { "https://example.com/uploads/default/original/1X/d1c2d40ab994e8410c.png" }

    it "should return the right part of url" do
      expect(Upload.extract_url(url).to_s).to eq("/original/1X/d1c2d40ab994e8410c.png")
    end
  end

  describe ".get_from_url" do
    let(:sha1) { "10f73034616a796dfd70177dc54b6def44c4ba6f" }
    let(:upload) { Fabricate(:upload, sha1: sha1) }

    it "works when the file has been uploaded" do
      expect(Upload.get_from_url(upload.url)).to eq(upload)
    end

    describe "for an extensionless url" do
      before do
        upload.update!(url: upload.url.sub(".png", ""))
        upload.reload
      end

      it "should return the right upload" do
        expect(Upload.get_from_url(upload.url)).to eq(upload)
      end
    end

    it "should return the right upload as long as the upload's URL matches" do
      upload.update!(url: "/uploads/default/12345/971308e535305c51.png")

      expect(Upload.get_from_url(upload.url)).to eq(upload)

      expect(Upload.get_from_url("/uploads/default/123131/971308e535305c51.png")).to eq(nil)
    end

    describe "for a url a tree" do
      before do
        upload.update!(
          url:
            Discourse.store.get_path_for("original", 16_001, upload.sha1, ".#{upload.extension}"),
        )
      end

      it "should return the right upload" do
        expect(Upload.get_from_url(upload.url)).to eq(upload)
      end
    end

    it "works when using a cdn" do
      begin
        original_asset_host = Rails.configuration.action_controller.asset_host
        Rails.configuration.action_controller.asset_host = "http://my.cdn.com"

        expect(Upload.get_from_url(URI.join("http://my.cdn.com", upload.url).to_s)).to eq(upload)
      ensure
        Rails.configuration.action_controller.asset_host = original_asset_host
      end
    end

    it "should return the right upload when using the full URL" do
      expect(
        Upload.get_from_url(URI.join("http://discourse.some.com:3000/", upload.url).to_s),
      ).to eq(upload)
    end

    it "doesn't blow up with an invalid URI" do
      expect { Upload.get_from_url("http://ip:port/index.html") }.not_to raise_error
      expect { Upload.get_from_url("mailto:admin%40example.com") }.not_to raise_error
      expect { Upload.get_from_url("mailto:example") }.not_to raise_error
    end

    describe "s3 store" do
      let(:upload) { Fabricate(:upload_s3) }
      let(:path) { upload.url.sub(SiteSetting.Upload.s3_base_url, "") }

      before { setup_s3 }

      it "can download an s3 upload" do
        stub_request(:get, upload.url).to_return(status: 200, body: "hello", headers: {})

        expect(upload.content).to eq("hello")
      end

      it "should return the right upload when using base url (not CDN) for s3" do
        upload
        expect(Upload.get_from_url(upload.url)).to eq(upload)
      end

      describe "when using a cdn" do
        let(:s3_cdn_url) { "https://mycdn.slowly.net" }

        before { SiteSetting.s3_cdn_url = s3_cdn_url }

        it "should return the right upload" do
          upload
          expect(Upload.get_from_url(URI.join(s3_cdn_url, path).to_s)).to eq(upload)
        end

        describe "when upload bucket contains subfolder" do
          before { SiteSetting.s3_upload_bucket = "s3-upload-bucket/path/path2" }

          it "should return the right upload" do
            upload
            expect(Upload.get_from_url(URI.join(s3_cdn_url, path).to_s)).to eq(upload)
          end
        end
      end

      it "should return the right upload when using one CDN for both s3 and assets" do
        begin
          original_asset_host = Rails.configuration.action_controller.asset_host
          cdn_url = "http://my.cdn.com"
          Rails.configuration.action_controller.asset_host = cdn_url
          SiteSetting.s3_cdn_url = cdn_url
          upload

          expect(Upload.get_from_url(URI.join(cdn_url, path).to_s)).to eq(upload)
        ensure
          Rails.configuration.action_controller.asset_host = original_asset_host
        end
      end
    end
  end

  describe ".get_from_urls" do
    let(:upload) { Fabricate(:upload, sha1: "10f73034616a796dfd70177dc54b6def44c4ba6f") }
    let(:upload2) { Fabricate(:upload, sha1: "2a7081e615f9075befd87a9a6d273935c0262cd5") }

    it "works with multiple uploads" do
      expect(Upload.get_from_urls([upload.url, upload2.url])).to contain_exactly(upload, upload2)
    end

    it "works for an extensionless URL" do
      url = upload.url.sub(".png", "")
      upload.update!(url: url)
      expect(Upload.get_from_urls([url])).to contain_exactly(upload)
    end

    it "works with uploads with mismatched URLs" do
      upload.update!(url: "/uploads/default/12345/971308e535305c51.png")
      expect(Upload.get_from_urls([upload.url])).to contain_exactly(upload)
      expect(Upload.get_from_urls(["/uploads/default/123131/971308e535305c51.png"])).to be_empty
    end

    it "works with an upload with a URL containing a deep tree" do
      upload.update!(
        url: Discourse.store.get_path_for("original", 16_001, upload.sha1, ".#{upload.extension}"),
      )
      expect(Upload.get_from_urls([upload.url])).to contain_exactly(upload)
    end

    it "works when using a CDN" do
      begin
        original_asset_host = Rails.configuration.action_controller.asset_host
        Rails.configuration.action_controller.asset_host = "http://my.cdn.com"

        expect(
          Upload.get_from_urls([URI.join("http://my.cdn.com", upload.url).to_s]),
        ).to contain_exactly(upload)
      ensure
        Rails.configuration.action_controller.asset_host = original_asset_host
      end
    end

    it "works with full URLs" do
      expect(
        Upload.get_from_urls([URI.join("http://discourse.some.com:3000/", upload.url).to_s]),
      ).to contain_exactly(upload)
    end

    it "handles invalid URIs" do
      urls = %w[http://ip:port/index.html mailto:admin%40example.com mailto:example]
      expect { Upload.get_from_urls(urls) }.not_to raise_error
    end
  end

  describe ".generate_digest" do
    it "should return the right digest" do
      expect(Upload.generate_digest(image.path)).to eq("bc975735dfc6409c1c2aa5ebf2239949bcbdbd65")
    end
  end

  describe ".short_url" do
    it "should generate a correct short url" do
      upload = Upload.new(sha1: "bda2c513e1da04f7b4e99230851ea2aafeb8cc4e", extension: "png")
      expect(upload.short_url).to eq("upload://r3AYqESanERjladb4vBB7VsMBm6.png")

      upload.extension = nil
      expect(upload.short_url).to eq("upload://r3AYqESanERjladb4vBB7VsMBm6")
    end
  end

  describe ".sha1_from_short_url" do
    it "should be able to look up sha1" do
      sha1 = "bda2c513e1da04f7b4e99230851ea2aafeb8cc4e"

      expect(Upload.sha1_from_short_url("upload://r3AYqESanERjladb4vBB7VsMBm6.png")).to eq(sha1)
      expect(Upload.sha1_from_short_url("upload://r3AYqESanERjladb4vBB7VsMBm6")).to eq(sha1)
      expect(Upload.sha1_from_short_url("r3AYqESanERjladb4vBB7VsMBm6")).to eq(sha1)
    end

    it "should be able to look up sha1 even with leading zeros" do
      sha1 = "0000c513e1da04f7b4e99230851ea2aafeb8cc4e"
      expect(Upload.sha1_from_short_url("upload://1Eg9p8rrCURq4T3a6iJUk0ri6.png")).to eq(sha1)
    end
  end

  describe ".sha1_from_long_url" do
    it "should be able to get the sha1 from a regular upload URL" do
      expect(
        Upload.sha1_from_long_url(
          "https://cdn.test.com/test/original/4X/7/6/5/1b6453892473a467d07372d45eb05abc2031647a.png",
        ),
      ).to eq("1b6453892473a467d07372d45eb05abc2031647a")
    end

    it "should be able to get the sha1 from a secure upload URL" do
      expect(
        Upload.sha1_from_long_url(
          "#{Discourse.base_url}\/secure-uploads/original/1X/1b6453892473a467d07372d45eb05abc2031647a.png",
        ),
      ).to eq("1b6453892473a467d07372d45eb05abc2031647a")
    end

    it "doesn't get a sha1 for a URL that does not match our scheme" do
      expect(
        Upload.sha1_from_long_url(
          "#{Discourse.base_url}\/blah/1b6453892473a467d07372d45eb05abc2031647a.png",
        ),
      ).to eq(nil)
    end
  end

  describe "#base62_sha1" do
    it "should return the right value" do
      upload.update!(sha1: "0000c513e1da04f7b4e99230851ea2aafeb8cc4e")
      expect(upload.base62_sha1).to eq("1Eg9p8rrCURq4T3a6iJUk0ri6")
    end
  end

  describe ".sha1_from_short_path" do
    it "should be able to lookup sha1" do
      path = "/uploads/short-url/3UjQ4jHoyeoQndk5y3qHzm3QVTQ.png"
      sha1 = "1b6453892473a467d07372d45eb05abc2031647a"

      expect(Upload.sha1_from_short_path(path)).to eq(sha1)
      expect(Upload.sha1_from_short_path(path.sub(".png", ""))).to eq(sha1)
    end
  end

  describe "#to_s" do
    it "should return the right value" do
      expect(upload.to_s).to eq(upload.url)
    end
  end

  describe ".migrate_to_new_scheme" do
    it "should not migrate system uploads" do
      SiteSetting.migrate_to_new_scheme = true

      expect { Upload.migrate_to_new_scheme }.to_not change { Upload.pluck(:url) }
    end
  end

  describe ".update_secure_status" do
    it "respects the override parameter if provided" do
      upload.update!(secure: true)

      upload.update_secure_status(override: true)

      expect(upload.secure).to eq(true)

      upload.update_secure_status(override: false)

      expect(upload.secure).to eq(false)
    end

    it "marks a local upload as not secure with default settings" do
      upload.update!(secure: true)
      expect { upload.update_secure_status }.to change { upload.secure }

      expect(upload.secure).to eq(false)
    end

    context "with local attachment" do
      before { SiteSetting.authorized_extensions = "pdf" }

      let(:upload) do
        Fabricate(:upload, original_filename: "small.pdf", extension: "pdf", secure: true)
      end

      it "marks a local attachment as secure if secure uploads enabled" do
        upload.update!(secure: false, access_control_post: Fabricate(:private_message_post))
        enable_secure_uploads

        expect { upload.update_secure_status }.to change { upload.secure }

        expect(upload.secure).to eq(true)
      end

      it "marks a local attachment as not secure if secure uploads enabled" do
        expect { upload.update_secure_status }.to change { upload.secure }

        expect(upload.secure).to eq(false)
      end
    end

    it "does not change secure status of a non-attachment when prevent_anons_from_downloading_files is enabled by itself" do
      SiteSetting.prevent_anons_from_downloading_files = true
      SiteSetting.authorized_extensions = "mp4"
      upload.update!(original_filename: "small.mp4", extension: "mp4")

      expect { upload.update_secure_status }.not_to change { upload.secure }

      expect(upload.secure).to eq(false)
    end

    context "with secure uploads enabled" do
      before { enable_secure_uploads }

      it "does not mark an image upload as not secure when there is no access control post id, to avoid unintentional exposure" do
        upload.update!(secure: true)
        upload.update_secure_status
        expect(upload.secure).to eq(true)
      end

      it "marks the upload as not secure if its access control post is a public post" do
        FileStore::S3Store.any_instance.expects(:update_upload_access_control).with(upload)
        upload.update!(secure: true, access_control_post: Fabricate(:post))
        upload.update_secure_status
        expect(upload.secure).to eq(false)
      end

      it "leaves the upload as secure if its access control post is a PM post" do
        upload.update!(secure: true, access_control_post: Fabricate(:private_message_post))
        upload.update_secure_status
        expect(upload.secure).to eq(true)
      end

      it "does not attempt to change the ACL if the secure status has not changed" do
        FileStore::S3Store.any_instance.expects(:update_upload_access_control).with(upload).never
        upload.update!(secure: true, access_control_post: Fabricate(:private_message_post))
        upload.update_secure_status
      end

      it "marks an image upload as secure if login_required is enabled" do
        SiteSetting.login_required = true
        upload.update!(secure: false)

        expect { upload.update_secure_status }.to change { upload.secure }

        expect(upload.reload.secure).to eq(true)
      end

      it "does not mark an upload used for a custom emoji as secure" do
        SiteSetting.login_required = true
        upload.update!(secure: false)
        CustomEmoji.create(name: "meme", upload: upload)
        upload.update_secure_status
        expect(upload.reload.secure).to eq(false)
      end

      it "does not mark an upload whose origin matches a regular emoji as secure (sometimes emojis are downloaded in pull_hotlinked_images)" do
        SiteSetting.login_required = true
        falafel =
          Emoji.all.find do |e|
            e.url == "/images/emoji/twitter/falafel.png?v=#{Emoji::EMOJI_VERSION}"
          end
        upload.update!(secure: false, origin: "http://localhost:3000#{falafel.url}")
        upload.update_secure_status
        expect(upload.reload.secure).to eq(false)
      end

      it "does not mark any upload with origin containing images/emoji in the URL" do
        SiteSetting.login_required = true
        upload.update!(secure: false, origin: "http://localhost:3000/images/emoji/test.png")
        upload.update_secure_status
        expect(upload.reload.secure).to eq(false)
      end

      it "does not throw an error if the object storage provider does not support ACLs" do
        FileStore::S3Store
          .any_instance
          .stubs(:update_upload_access_control)
          .raises(
            Aws::S3::Errors::NotImplemented.new(
              "A header you provided implies functionality that is not implemented",
              "",
            ),
          )
        upload.update!(secure: true, access_control_post: Fabricate(:private_message_post))
        expect { upload.update_secure_status }.not_to raise_error
      end

      it "succeeds even if the extension of the upload is not authorized" do
        upload.update!(secure: false, access_control_post: Fabricate(:private_message_post))
        SiteSetting.login_required = true
        SiteSetting.authorized_extensions = ""
        upload.update_secure_status
        upload.reload
        expect(upload.secure).to eq(true)
      end

      it "respects the authorized extensions when creating a new upload, no matter its secure status" do
        SiteSetting.login_required = true
        SiteSetting.authorized_extensions = ""
        expect do
          Fabricate(
            :upload,
            access_control_post: Fabricate(:private_message_post),
            security_last_changed_at: Time.zone.now,
            security_last_changed_reason: "test",
            secure: true,
          )
        end.to raise_error(ActiveRecord::RecordInvalid)
      end

      context "when secure_uploads_pm_only is true" do
        before { SiteSetting.secure_uploads_pm_only = true }

        it "does not mark an image upload as secure if login_required is enabled" do
          SiteSetting.login_required = true
          upload.update!(secure: false)
          expect { upload.update_secure_status }.not_to change { upload.secure }
          expect(upload.reload.secure).to eq(false)
        end

        it "marks the upload as not secure if its access control post is a public post" do
          upload.update!(secure: true, access_control_post: Fabricate(:post))
          upload.update_secure_status
          expect(upload.secure).to eq(false)
        end

        it "leaves the upload as secure if its access control post is a PM post" do
          upload.update!(secure: true, access_control_post: Fabricate(:private_message_post))
          upload.update_secure_status
          expect(upload.secure).to eq(true)
        end
      end
    end

    context "with optimized videos" do
      before do
        extensions = SiteSetting.authorized_extensions.split("|")
        SiteSetting.authorized_extensions = (extensions | %w[mp4 mov avi mkv]).join("|")
        enable_secure_uploads
      end

      it "syncs optimized video secure status when original upload secure status changes from false to true" do
        original_upload = Fabricate(:upload, secure: false)
        optimized_video = Fabricate(:optimized_video, upload: original_upload)
        optimized_upload = optimized_video.optimized_upload
        optimized_upload.update!(secure: false)

        FileStore::S3Store.any_instance.expects(:update_upload_access_control).with(original_upload)
        FileStore::S3Store
          .any_instance
          .expects(:update_upload_access_control)
          .with(optimized_upload)

        original_upload.update!(access_control_post: Fabricate(:private_message_post))
        original_upload.update_secure_status

        expect(original_upload.reload.secure).to eq(true)
        expect(optimized_upload.reload.secure).to eq(true)
      end

      it "syncs optimized video secure status when original upload secure status changes from true to false" do
        original_upload =
          Fabricate(:upload, secure: true, access_control_post: Fabricate(:private_message_post))
        optimized_video = Fabricate(:optimized_video, upload: original_upload)
        optimized_upload = optimized_video.optimized_upload
        optimized_upload.update!(secure: true)

        FileStore::S3Store.any_instance.expects(:update_upload_access_control).with(original_upload)
        FileStore::S3Store
          .any_instance
          .expects(:update_upload_access_control)
          .with(optimized_upload)

        original_upload.update!(access_control_post: Fabricate(:post))
        original_upload.update_secure_status

        expect(original_upload.reload.secure).to eq(false)
        expect(optimized_upload.reload.secure).to eq(false)
      end

      it "does not update optimized video secure status if it already matches" do
        original_upload =
          Fabricate(:upload, secure: true, access_control_post: Fabricate(:private_message_post))
        optimized_video = Fabricate(:optimized_video, upload: original_upload)
        optimized_upload = optimized_video.optimized_upload
        optimized_upload.update!(secure: true)

        FileStore::S3Store
          .any_instance
          .expects(:update_upload_access_control)
          .with(original_upload)
          .never

        original_upload.update_secure_status

        expect(original_upload.reload.secure).to eq(true)
        expect(optimized_upload.reload.secure).to eq(true)
      end

      it "syncs multiple optimized videos when original upload secure status changes" do
        original_upload = Fabricate(:upload, secure: false)
        optimized_video1 =
          Fabricate(:optimized_video, upload: original_upload, adapter: "aws_mediaconvert")
        optimized_video2 =
          Fabricate(:optimized_video, upload: original_upload, adapter: "other_adapter")
        optimized_upload1 = optimized_video1.optimized_upload
        optimized_upload2 = optimized_video2.optimized_upload
        optimized_upload1.update!(secure: false)
        optimized_upload2.update!(secure: false)

        FileStore::S3Store.any_instance.expects(:update_upload_access_control).with(original_upload)
        FileStore::S3Store
          .any_instance
          .expects(:update_upload_access_control)
          .with(optimized_upload1)
        FileStore::S3Store
          .any_instance
          .expects(:update_upload_access_control)
          .with(optimized_upload2)

        original_upload.update!(access_control_post: Fabricate(:private_message_post))
        original_upload.update_secure_status

        expect(original_upload.reload.secure).to eq(true)
        expect(optimized_upload1.reload.secure).to eq(true)
        expect(optimized_upload2.reload.secure).to eq(true)
      end
    end
  end

  describe ".extract_upload_ids" do
    let(:upload) { Fabricate(:upload) }

    it "works with short URLs" do
      ids = Upload.extract_upload_ids("This URL #{upload.short_url} is an upload")
      expect(ids).to contain_exactly(upload.id)
    end

    it "works with SHA1s" do
      ids = Upload.extract_upload_ids("This URL /#{upload.sha1} is an upload")
      expect(ids).to contain_exactly(upload.id)
    end

    it "works with Base62 hashes" do
      ids = Upload.extract_upload_ids("This URL /#{Upload.base62_sha1(upload.sha1)} is an upload")
      expect(ids).to contain_exactly(upload.id)
    end

    it "works with shorter base62 hashes (when sha1 has leading 0s)" do
      upload.update(sha1: "0000c513e1da04f7b4e99230851ea2aafeb8cc4e")
      base62 = Upload.base62_sha1(upload.sha1).delete_prefix("0")
      ids = Upload.extract_upload_ids("This URL /#{base62} is an upload")
      expect(ids).to contain_exactly(upload.id)
    end
  end

  describe ".sha1_from_base62_encoded" do
    it "rejects base62 strings that are too long" do
      long_base62 = "A" * 1000
      expect(Upload.sha1_from_base62_encoded(long_base62)).to be_nil
    end
  end

  def enable_secure_uploads
    setup_s3
    SiteSetting.secure_uploads = true
    stub_upload(upload)
  end

  describe ".destroy" do
    it "can correctly clear information when destroying an upload" do
      upload = Fabricate(:upload)
      user = Fabricate(:user)

      user.user_profile.update!(
        card_background_upload_id: upload.id,
        profile_background_upload_id: upload.id,
      )

      upload.destroy

      user.user_profile.reload

      expect(user.user_profile.card_background_upload_id).to eq(nil)
      expect(user.user_profile.profile_background_upload_id).to eq(nil)
    end
  end

  describe ".secure_uploads_url_from_upload_url" do
    before do
      # must be done so signed_url_for_path exists
      enable_secure_uploads
    end

    it "gets the secure uploads url from an S3 upload url" do
      upload = Fabricate(:upload_s3, secure: true)
      url = upload.url
      secure_url = Upload.secure_uploads_url_from_upload_url(url)
      expect(secure_url).not_to include(SiteSetting.Upload.absolute_base_url)
    end
  end

  describe ".secure_uploads_url?" do
    it "works for a secure uploads url with or without schema + host" do
      url =
        "//localhost:3000/secure-uploads/original/2X/f/f62055931bb702c7fd8f552fb901f977e0289a18.png"
      expect(Upload.secure_uploads_url?(url)).to eq(true)
      url = "/secure-uploads/original/2X/f/f62055931bb702c7fd8f552fb901f977e0289a18.png"
      expect(Upload.secure_uploads_url?(url)).to eq(true)
      url =
        "http://localhost:3000/secure-uploads/original/2X/f/f62055931bb702c7fd8f552fb901f977e0289a18.png"
      expect(Upload.secure_uploads_url?(url)).to eq(true)
    end

    it "does not get false positives on a topic url" do
      url = "/t/secure-uploads-are-cool/42839"
      expect(Upload.secure_uploads_url?(url)).to eq(false)
    end

    it "returns true only for secure uploads URL for actual media (images/video/audio)" do
      url = "/secure-uploads/original/2X/f/f62055931bb702c7fd8f552fb901f977e0289a18.mp4"
      expect(Upload.secure_uploads_url?(url)).to eq(true)
      url = "/secure-uploads/original/2X/f/f62055931bb702c7fd8f552fb901f977e0289a18.png"
      expect(Upload.secure_uploads_url?(url)).to eq(true)
      url = "/secure-uploads/original/2X/f/f62055931bb702c7fd8f552fb901f977e0289a18.mp3"
      expect(Upload.secure_uploads_url?(url)).to eq(true)
      url = "/secure-uploads/original/2X/f/f62055931bb702c7fd8f552fb901f977e0289a18.pdf"
      expect(Upload.secure_uploads_url?(url)).to eq(false)
    end

    it "does not work for regular upload urls" do
      url = "/uploads/default/test_0/original/1X/e1864389d8252958586c76d747b069e9f68827e3.png"
      expect(Upload.secure_uploads_url?(url)).to eq(false)
    end

    it "does not raise for invalid URLs" do
      url = "http://URL:%20https://google.com"
      expect(Upload.secure_uploads_url?(url)).to eq(false)
    end
  end

  describe "#dominant_color" do
    let(:white_image) { Fabricate(:image_upload, color: "white") }
    let(:red_image) { Fabricate(:image_upload, color: "red") }
    let(:high_color_image) { Fabricate(:image_upload, color: "#000A00F00", color_depth: 16) }
    let(:not_an_image) do
      upload = Fabricate(:upload)

      file = Tempfile.new(%w[invalid .txt])
      file << "Not really an image"
      file.rewind

      upload.update(url: Discourse.store.store_upload(file, upload), extension: "txt")
      upload
    end
    let(:invalid_image) do
      upload = Fabricate(:upload)

      file = Tempfile.new(%w[invalid .png])
      file << "Not really an image"
      file.rewind

      upload.update(url: Discourse.store.store_upload(file, upload))
      upload
    end

    it "correctly identifies and stores an image's dominant color" do
      expect(white_image.dominant_color).to eq(nil)
      expect(white_image.dominant_color(calculate_if_missing: true)).to eq("FFFFFF")
      expect(white_image.dominant_color).to eq("FFFFFF")

      expect(red_image.dominant_color).to eq(nil)
      expect(red_image.dominant_color(calculate_if_missing: true)).to eq("FF0000")
      expect(red_image.dominant_color).to eq("FF0000")

      expect(high_color_image.dominant_color).to eq(nil)
      # original is: #000A00F00
      # downsamples to: #009FEF
      # A00 is closer to 9F than A0
      # EF is closer to F00 than F0
      expect(high_color_image.dominant_color(calculate_if_missing: true)).to eq("009FEF")
      expect(high_color_image.dominant_color).to eq("009FEF")
    end

    it "can be backfilled" do
      expect(white_image.dominant_color).to eq(nil)
      expect(red_image.dominant_color).to eq(nil)

      Upload.backfill_dominant_colors!(5)

      white_image.reload
      red_image.reload

      expect(white_image.dominant_color).to eq("FFFFFF")
      expect(red_image.dominant_color).to eq("FF0000")
    end

    it "is backfilled by the job" do
      expect(white_image.dominant_color).to eq(nil)
      expect(red_image.dominant_color).to eq(nil)

      Jobs::BackfillDominantColors.new.execute({})

      white_image.reload
      red_image.reload

      expect(white_image.dominant_color).to eq("FFFFFF")
      expect(red_image.dominant_color).to eq("FF0000")
    end

    it "stores an empty string for non-image uploads" do
      expect(not_an_image.dominant_color).to eq(nil)
      expect(not_an_image.dominant_color(calculate_if_missing: true)).to eq("")
      expect(not_an_image.dominant_color).to eq("")
    end

    it "correctly handles invalid image files" do
      expect(invalid_image.dominant_color).to eq(nil)
      expect(invalid_image.dominant_color(calculate_if_missing: true)).to eq("")
      expect(invalid_image.dominant_color).to eq("")
    end

    it "correctly handles unparsable ImageMagick output" do
      Discourse::Utils.stubs(:execute_command).returns("someinvalidoutput")

      expect(invalid_image.dominant_color).to eq(nil)

      expect { invalid_image.dominant_color(calculate_if_missing: true) }.to raise_error(
        /Calculated dominant color but unable to parse output/,
      )

      expect(invalid_image.dominant_color).to eq(nil)
    end

    it "correctly handles error when file is too large to download" do
      white_image.stubs(:local?).returns(false)
      FileStore::LocalStore.any_instance.stubs(:download).returns(nil).once

      expect(white_image.dominant_color).to eq(nil)
      expect(white_image.dominant_color(calculate_if_missing: true)).to eq("")
      expect(white_image.dominant_color).to eq("")
    end

    it "correctly handles error when file has HTTP error" do
      white_image.stubs(:local?).returns(false)
      FileStore::LocalStore
        .any_instance
        .stubs(:download)
        .raises(OpenURI::HTTPError.new("Error", nil))
        .once

      expect(white_image.dominant_color).to eq(nil)
      expect(white_image.dominant_color(calculate_if_missing: true)).to eq("")
      expect(white_image.dominant_color).to eq("")
    end

    it "is validated for length" do
      u = Fabricate(:upload)

      # Acceptable values
      u.update!(dominant_color: nil)
      u.update!(dominant_color: "")
      u.update!(dominant_color: "abcdef")

      expect { u.update!(dominant_color: "toomanycharacters") }.to raise_error(
        ActiveRecord::RecordInvalid,
      )

      expect { u.update!(dominant_color: "abcd") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe ".mark_invalid_s3_uploads_as_missing" do
    it "should update all upload records with a `verification_status` of `invalid_etag` to `s3_file_missing`" do
      upload_1 =
        Fabricate(:upload_s3, verification_status: Upload.verification_statuses[:invalid_etag])

      upload_2 =
        Fabricate(:upload_s3, verification_status: Upload.verification_statuses[:invalid_etag])

      upload_3 = Fabricate(:upload_s3, verification_status: Upload.verification_statuses[:verified])

      Upload.mark_invalid_s3_uploads_as_missing

      expect(upload_1.reload.verification_status).to eq(
        Upload.verification_statuses[:s3_file_missing_confirmed],
      )

      expect(upload_2.reload.verification_status).to eq(
        Upload.verification_statuses[:s3_file_missing_confirmed],
      )

      expect(upload_3.reload.verification_status).to eq(Upload.verification_statuses[:verified])
    end
  end
end
