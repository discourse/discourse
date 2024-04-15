# frozen_string_literal: true
# rubocop:disable Discourse/OnlyTopLevelMultisiteSpecs

require_relative "shared_context_for_backup_restore"

RSpec.describe BackupRestore::UploadsRestorer do
  subject(:restorer) { BackupRestore::UploadsRestorer.new(logger) }

  include_context "with shared backup restore context"

  def with_temp_uploads_directory(name: "default", with_optimized: false)
    Dir.mktmpdir do |directory|
      path = File.join(directory, "uploads", name)
      FileUtils.mkdir_p(path)
      FileUtils.mkdir(File.join(path, "optimized")) if with_optimized
      yield(directory, path)
    end
  end

  def expect_no_remap(source_site_name: nil, target_site_name:, metadata: [])
    expect_remaps(
      source_site_name: source_site_name,
      target_site_name: target_site_name,
      metadata: metadata,
    )
  end

  def expect_remap(
    source_site_name: nil,
    target_site_name:,
    metadata: [],
    from:,
    to:,
    regex: false,
    &block
  )
    expect_remaps(
      source_site_name: source_site_name,
      target_site_name: target_site_name,
      metadata: metadata,
      remaps: [{ from: from, to: to, regex: regex }],
      &block
    )
  end

  def expect_remaps(source_site_name: nil, target_site_name:, metadata: [], remaps: [], &block)
    regex_remaps = remaps.select { |r| r[:regex] }
    remaps.delete_if { |r| r.delete(:regex) }

    source_site_name ||= metadata.find { |d| d[:name] == "db_name" }&.dig(:value) || "default"

    if source_site_name != target_site_name
      site_rename = { from: "/uploads/#{source_site_name}/", to: uploads_path(target_site_name) }
      remaps << site_rename unless remaps.last == site_rename
    end

    with_temp_uploads_directory(name: source_site_name, with_optimized: true) do |directory, path|
      yield(directory) if block_given?

      Discourse.store.class.any_instance.expects(:copy_from).with(path).once

      if remaps.blank?
        DbHelper.expects(:remap).never
      else
        DbHelper
          .expects(:remap)
          .with do |from, to, args|
            args[:excluded_tables]&.include?("backup_metadata")
            remaps.shift == { from: from, to: to }
          end
          .times(remaps.size)
      end

      if regex_remaps.blank?
        DbHelper.expects(:regexp_replace).never
      else
        DbHelper
          .expects(:regexp_replace)
          .with do |from, to, args|
            args[:excluded_tables]&.include?("backup_metadata")
            regex_remaps.shift == { from: from, to: to }
          end
          .times(regex_remaps.size)
      end

      if target_site_name == "default"
        setup_and_restore(directory, metadata)
      else
        test_multisite_connection(target_site_name) { setup_and_restore(directory, metadata) }
      end
    end
  end

  def setup_and_restore(directory, metadata)
    metadata.each { |d| BackupMetadata.create!(d) }
    restorer.restore(directory)
  end

  def uploads_path(database)
    path = File.join("uploads", database)

    path = File.join(path, "test_#{ENV["TEST_ENV_NUMBER"].presence || "0"}")

    "/#{path}/"
  end

  def s3_url_regex(bucket, path)
    Regexp.escape("//#{bucket}") +
      %q*\.s3(?:\.dualstack\.[a-z0-9\-]+?|[.\-][a-z0-9\-]+?)?\.amazonaws\.com* + Regexp.escape(path)
  end

  describe "uploads" do
    let!(:multisite) { { name: "multisite", value: true } }
    let!(:no_multisite) { { name: "multisite", value: false } }
    let!(:source_db_name) { { name: "db_name", value: "foo" } }
    let!(:base_url) { { name: "base_url", value: "https://test.localhost/forum" } }
    let!(:no_cdn_url) { { name: "cdn_url", value: nil } }
    let!(:cdn_url) { { name: "cdn_url", value: "https://some-cdn.example.com" } }
    let(:target_site_name) { target_site_type == multisite ? "second" : "default" }
    let(:target_hostname) { target_site_type == multisite ? "test2.localhost" : "test.localhost" }

    shared_examples "with no uploads" do
      it "does nothing when temporary uploads directory is missing or empty" do
        store_class.any_instance.expects(:copy_from).never

        Dir.mktmpdir do |directory|
          restorer.restore(directory)

          FileUtils.mkdir(File.join(directory, "uploads"))
          restorer.restore(directory)
        end
      end
    end

    shared_examples "without metadata" do
      it "correctly remaps uploads" do
        expect_no_remap(target_site_name: "default")
      end

      it "correctly remaps when site name is different" do
        expect_remap(
          source_site_name: "foo",
          target_site_name: "default",
          from: "/uploads/foo/",
          to: uploads_path("default"),
        )
      end
    end

    shared_context "when restoring uploads" do
      before do
        Upload.where("id > 0").destroy_all
        Fabricate(:optimized_image)

        upload = Fabricate(:upload_s3)
        post =
          Fabricate(
            :post,
            raw: "![#{upload.original_filename}](#{upload.short_url})",
            user: Fabricate(:user, refresh_auto_groups: true),
          )
        post.link_post_uploads

        FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"))
        FileStore::S3Store
          .any_instance
          .stubs(:store_upload)
          .returns do
            File.join(
              "//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com",
              target_site_type == multisite ? "/uploads/#{target_site_name}" : "",
              "original/1X/bc975735dfc6409c1c2aa5ebf2239949bcbdbd65.png",
            )
          end
        UserAvatar.import_url_for_user("logo.png", Fabricate(:user))
      end

      it "successfully restores uploads" do
        SiteIconManager.expects(:ensure_optimized!).once

        with_temp_uploads_directory do |directory, path|
          store_class.any_instance.expects(:copy_from).with(path).once

          expect { restorer.restore(directory) }.to change { OptimizedImage.count }.by_at_most(
            -1,
          ).and change { Jobs::CreateAvatarThumbnails.jobs.size }.by(1).and change {
                        Post.where(baked_version: nil).count
                      }.by(1)
        end
      end

      it "doesn't generate optimized images when backup contains optimized images" do
        SiteIconManager.expects(:ensure_optimized!).never

        with_temp_uploads_directory(with_optimized: true) do |directory, path|
          store_class.any_instance.expects(:copy_from).with(path).once

          expect { restorer.restore(directory) }.to not_change {
            OptimizedImage.count
          }.and not_change { Jobs::CreateAvatarThumbnails.jobs.size }.and change {
                        Post.where(baked_version: nil).count
                      }.by(1)
        end
      end
    end

    shared_examples "common remaps" do
      it "remaps when `base_url` changes" do
        Discourse.expects(:base_url).returns("http://localhost").at_least_once

        expect_remap(
          target_site_name: target_site_name,
          metadata: [source_site_type, base_url],
          from: "https://test.localhost/forum",
          to: "http://localhost",
        )
      end

      it "doesn't remap when `cdn_url` in `backup_metadata` is empty" do
        expect_no_remap(
          target_site_name: target_site_name,
          metadata: [source_site_type, no_cdn_url],
        )
      end

      it "remaps to new `cdn_url` when `cdn_url` changes to a different value" do
        Discourse.expects(:asset_host).returns("https://new-cdn.example.com").at_least_once

        expect_remaps(
          target_site_name: target_site_name,
          metadata: [source_site_type, cdn_url],
          remaps: [
            { from: "https://some-cdn.example.com/", to: "https://new-cdn.example.com/" },
            { from: "some-cdn.example.com", to: "new-cdn.example.com" },
          ],
        )
      end

      it "remaps to `base_url` when `cdn_url` changes to an empty value" do
        Discourse.expects(:base_url).returns("http://example.com/discourse").at_least_once
        Discourse.expects(:asset_host).returns(nil).at_least_once

        expect_remaps(
          target_site_name: target_site_name,
          metadata: [source_site_type, cdn_url],
          remaps: [
            { from: "https://some-cdn.example.com/", to: "//example.com/discourse/" },
            { from: "some-cdn.example.com", to: "example.com" },
          ],
        )
      end
    end

    shared_examples "remaps from local storage" do
      it "doesn't remap when `s3_base_url` in `backup_metadata` is empty" do
        expect_no_remap(
          target_site_name: target_site_name,
          metadata: [source_site_type, s3_base_url],
        )
      end

      it "doesn't remap when `s3_cdn_url` in `backup_metadata` is empty" do
        expect_no_remap(
          target_site_name: target_site_name,
          metadata: [source_site_type, s3_cdn_url],
        )
      end
    end

    context "when currently stored locally" do
      before { SiteSetting.enable_s3_uploads = false }

      let!(:store_class) { FileStore::LocalStore }

      include_context "with no uploads"
      include_context "when restoring uploads"

      context "with remaps" do
        include_examples "without metadata"

        context "when uploads previously stored locally" do
          let!(:s3_base_url) { { name: "s3_base_url", value: nil } }
          let!(:s3_cdn_url) { { name: "s3_cdn_url", value: nil } }

          context "with regular site as source" do
            let!(:source_site_type) { no_multisite }

            context "with regular site as target" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end

            context "with multisite as target", type: :multisite do
              let!(:target_site_type) { multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end
          end

          context "with multisite as source" do
            let!(:source_site_type) { multisite }

            context "with regular site as target" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end

            context "with multisite as target", type: :multisite do
              let!(:target_site_type) { multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end
          end
        end

        context "with uploads previously stored on S3" do
          let!(:s3_base_url) do
            { name: "s3_base_url", value: "//old-bucket.s3-us-east-1.amazonaws.com" }
          end
          let!(:s3_cdn_url) { { name: "s3_cdn_url", value: "https://s3-cdn.example.com" } }

          shared_examples "regular site remaps from S3" do
            it "remaps when `s3_base_url` changes" do
              expect_remap(
                target_site_name: target_site_name,
                metadata: [no_multisite, s3_base_url],
                from: s3_url_regex("old-bucket", "/"),
                to: uploads_path(target_site_name),
                regex: true,
              )
            end

            it "remaps when `s3_cdn_url` changes" do
              expect_remaps(
                target_site_name: target_site_name,
                metadata: [no_multisite, s3_cdn_url],
                remaps: [
                  {
                    from: "https://s3-cdn.example.com/",
                    to: "//#{target_hostname}#{uploads_path(target_site_name)}",
                  },
                  { from: "s3-cdn.example.com", to: target_hostname },
                ],
              )
            end
          end

          shared_examples "multisite remaps from S3" do
            it "remaps when `s3_base_url` changes" do
              expect_remap(
                target_site_name: target_site_name,
                metadata: [source_db_name, multisite, s3_base_url],
                from: s3_url_regex("old-bucket", "/"),
                to: "/",
                regex: true,
              )
            end

            it "remaps when `s3_cdn_url` changes" do
              expect_remaps(
                target_site_name: target_site_name,
                metadata: [source_db_name, multisite, s3_cdn_url],
                remaps: [
                  { from: "https://s3-cdn.example.com/", to: "//#{target_hostname}/" },
                  { from: "s3-cdn.example.com", to: target_hostname },
                ],
              )
            end
          end

          context "with regular site as source" do
            let!(:source_site_type) { no_multisite }

            context "with regular site as target" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "regular site remaps from S3"
            end

            context "with multisite as target", type: :multisite do
              let!(:target_site_type) { multisite }

              include_examples "common remaps"
              include_examples "regular site remaps from S3"
            end
          end

          context "with multisite as source" do
            let!(:source_site_type) { multisite }

            context "with regular site as target" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "multisite remaps from S3"
            end

            context "with multisite as target", type: :multisite do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "multisite remaps from S3"
            end
          end
        end
      end
    end

    context "when currently stored on S3" do
      before { setup_s3 }

      let!(:store_class) { FileStore::S3Store }

      include_context "with no uploads"
      include_context "when restoring uploads"

      context "with remaps" do
        include_examples "without metadata"

        context "with uploads previously stored locally" do
          let!(:s3_base_url) { { name: "s3_base_url", value: nil } }
          let!(:s3_cdn_url) { { name: "s3_cdn_url", value: nil } }

          context "with regular site as source" do
            let!(:source_site_type) { no_multisite }

            context "with regular site as target" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end

            context "with multisite as target", type: :multisite do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end
          end

          context "with multisite as source" do
            let!(:source_site_type) { multisite }

            context "with regular site as target" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end

            context "with multisite as target", type: :multisite do
              let!(:target_site_type) { multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end
          end
        end

        context "with uploads previously stored on S3" do
          let!(:s3_base_url) do
            { name: "s3_base_url", value: "//old-bucket.s3-us-east-1.amazonaws.com" }
          end
          let!(:s3_cdn_url) { { name: "s3_cdn_url", value: "https://s3-cdn.example.com" } }

          shared_examples "regular site remaps from S3" do
            it "remaps when `s3_base_url` changes" do
              expect_remap(
                target_site_name: target_site_name,
                metadata: [no_multisite, s3_base_url],
                from: s3_url_regex("old-bucket", "/"),
                to: uploads_path(target_site_name),
                regex: true,
              )
            end

            it "remaps when `s3_cdn_url` changes" do
              SiteSetting::Upload
                .expects(:s3_cdn_url)
                .returns("https://new-s3-cdn.example.com")
                .at_least_once

              expect_remaps(
                target_site_name: target_site_name,
                metadata: [no_multisite, s3_cdn_url],
                remaps: [
                  {
                    from: "https://s3-cdn.example.com/",
                    to: "https://new-s3-cdn.example.com#{uploads_path(target_site_name)}",
                  },
                  { from: "s3-cdn.example.com", to: "new-s3-cdn.example.com" },
                ],
              )
            end
          end

          shared_examples "multisite remaps from S3" do
            it "remaps when `s3_base_url` changes" do
              expect_remap(
                target_site_name: target_site_name,
                metadata: [source_db_name, multisite, s3_base_url],
                from: s3_url_regex("old-bucket", "/"),
                to: "/",
                regex: true,
              )
            end

            context "when `s3_cdn_url` is configured" do
              it "remaps when `s3_cdn_url` changes" do
                SiteSetting::Upload
                  .expects(:s3_cdn_url)
                  .returns("http://new-s3-cdn.example.com")
                  .at_least_once

                expect_remaps(
                  target_site_name: target_site_name,
                  metadata: [source_db_name, multisite, s3_cdn_url],
                  remaps: [
                    { from: "https://s3-cdn.example.com/", to: "//new-s3-cdn.example.com/" },
                    { from: "s3-cdn.example.com", to: "new-s3-cdn.example.com" },
                  ],
                )
              end
            end

            context "when `s3_cdn_url` is not configured" do
              it "remaps to `base_url` when `s3_cdn_url` changes" do
                SiteSetting::Upload.expects(:s3_cdn_url).returns(nil).at_least_once

                expect_remaps(
                  target_site_name: target_site_name,
                  metadata: [source_db_name, multisite, s3_cdn_url],
                  remaps: [
                    { from: "https://s3-cdn.example.com/", to: "//#{target_hostname}/" },
                    { from: "s3-cdn.example.com", to: target_hostname },
                  ],
                )
              end
            end
          end

          context "with regular site as source" do
            let!(:source_site_type) { no_multisite }

            context "with regular site as target" do
              let!(:target_site_name) { "default" }
              let!(:target_hostname) { "test.localhost" }

              include_examples "common remaps"
              include_examples "regular site remaps from S3"
            end

            context "with multisite as target", type: :multisite do
              let!(:target_site_name) { "second" }
              let!(:target_hostname) { "test2.localhost" }

              include_examples "common remaps"
              include_examples "regular site remaps from S3"
            end
          end

          context "with multisite as source" do
            let!(:source_site_type) { multisite }

            context "with regular site as target" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "multisite remaps from S3"
            end

            context "with multisite as target", type: :multisite do
              let!(:target_site_type) { multisite }

              include_examples "common remaps"
              include_examples "multisite remaps from S3"
            end
          end
        end
      end
    end
  end

  describe ".s3_regex_string" do
    def regex_matches(s3_base_url)
      regex, _ = BackupRestore::UploadsRestorer.s3_regex_string(s3_base_url)
      expect(Regexp.new(regex)).to match(s3_base_url)
    end

    it "correctly matches different S3 base URLs" do
      regex_matches("//some-bucket.s3.amazonaws.com/")
      regex_matches("//some-bucket.s3.us-west-2.amazonaws.com/")
      regex_matches("//some-bucket.s3-us-west-2.amazonaws.com/")
      regex_matches("//some-bucket.s3.dualstack.us-west-2.amazonaws.com/")
      regex_matches("//some-bucket.s3.cn-north-1.amazonaws.com.cn/")

      regex_matches("//some-bucket.s3.amazonaws.com/foo/")
      regex_matches("//some-bucket.s3.us-east-2.amazonaws.com/foo/")
      regex_matches("//some-bucket.s3-us-east-2.amazonaws.com/foo/")
      regex_matches("//some-bucket.s3.dualstack.us-east-2.amazonaws.com/foo/")
      regex_matches("//some-bucket.s3.cn-north-1.amazonaws.com.cn/foo/")
    end
  end

  it "raises an exception when the store doesn't support the copy_from method" do
    Discourse.stubs(:store).returns(Object.new)

    with_temp_uploads_directory do |directory|
      expect { restorer.restore(directory) }.to raise_error(BackupRestore::UploadsRestoreError)
    end
  end

  it "raises an exception when there are multiple folders in the uploads directory" do
    with_temp_uploads_directory do |directory|
      FileUtils.mkdir_p(File.join(directory, "uploads", "foo"))
      expect { restorer.restore(directory) }.to raise_error(BackupRestore::UploadsRestoreError)
    end
  end

  it "ignores 'PaxHeaders' and hidden directories within the uploads directory" do
    expect_remap(
      source_site_name: "xylan",
      target_site_name: "default",
      from: "/uploads/xylan/",
      to: uploads_path("default"),
    ) do |directory|
      FileUtils.mkdir_p(File.join(directory, "uploads", "PaxHeaders.27134"))
      FileUtils.mkdir_p(File.join(directory, "uploads", ".hidden"))
    end
  end
end
