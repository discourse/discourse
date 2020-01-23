# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_context_for_backup_restore'

describe BackupRestore::UploadsRestorer do
  include_context "shared stuff"

  subject { BackupRestore::UploadsRestorer.new(logger) }

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
      metadata: metadata
    )
  end

  def expect_remap(source_site_name: nil, target_site_name:, metadata: [], from:, to:, &block)
    expect_remaps(
      source_site_name: source_site_name,
      target_site_name: target_site_name,
      metadata: metadata,
      remaps: [{ from: from, to: to }],
      &block
    )
  end

  def expect_remaps(source_site_name: nil, target_site_name:, metadata: [], remaps: [], &block)
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
        DbHelper.expects(:remap).with do |from, to, args|
          args[:excluded_tables]&.include?("backup_metadata")
          remaps.shift == { from: from, to: to }
        end.times(remaps.size)
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
    subject.restore(directory)
  end

  def uploads_path(database)
    path = File.join("uploads", database)

    if Discourse.is_parallel_test?
      path = File.join(path, ENV['TEST_ENV_NUMBER'].presence || '1')
    end

    "/#{path}/"
  end

  context "uploads" do
    let!(:multisite) { { name: "multisite", value: true } }
    let!(:no_multisite) { { name: "multisite", value: false } }
    let!(:source_db_name) { { name: "db_name", value: "foo" } }
    let!(:base_url) { { name: "base_url", value: "https://www.example.com/forum" } }
    let!(:no_cdn_url)  { { name: "cdn_url", value: nil } }
    let!(:cdn_url)  { { name: "cdn_url", value: "https://some-cdn.example.com" } }
    let(:target_site_name) { target_site_type == multisite ? "second" : "default" }
    let(:target_hostname) { target_site_type == multisite ? "test2.localhost" : "test.localhost" }

    shared_context "no uploads" do
      it "does nothing when temporary uploads directory is missing or empty" do
        store_class.any_instance.expects(:copy_from).never

        Dir.mktmpdir do |directory|
          subject.restore(directory)

          FileUtils.mkdir(File.join(directory, "uploads"))
          subject.restore(directory)
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
          to: uploads_path("default")
        )
      end
    end

    shared_context "restores uploads" do
      before do
        Upload.where("id > 0").destroy_all
        Fabricate(:optimized_image)

        upload = Fabricate(:upload_s3)
        post = Fabricate(:post, raw: "![#{upload.original_filename}](#{upload.short_url})")
        post.link_post_uploads

        FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"))
        FileStore::S3Store.any_instance.stubs(:store_upload).returns do
          File.join(
            "//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com",
            target_site_type == multisite ? "/uploads/#{target_site_name}" : "",
            "original/1X/bc975735dfc6409c1c2aa5ebf2239949bcbdbd65.png"
          )
        end
        UserAvatar.import_url_for_user("logo.png", Fabricate(:user))
      end

      it "successfully restores uploads" do
        SiteIconManager.expects(:ensure_optimized!).once

        with_temp_uploads_directory do |directory, path|
          store_class.any_instance.expects(:copy_from).with(path).once

          expect { subject.restore(directory) }
            .to change { OptimizedImage.count }.by_at_most(-1)
            .and change { Jobs::CreateAvatarThumbnails.jobs.size }.by(1)
            .and change { Post.where(baked_version: nil).count }.by(1)
        end
      end

      it "doesn't generate optimized images when backup contains optimized images" do
        SiteIconManager.expects(:ensure_optimized!).never

        with_temp_uploads_directory(with_optimized: true) do |directory, path|
          store_class.any_instance.expects(:copy_from).with(path).once

          expect { subject.restore(directory) }
            .to change { OptimizedImage.count }.by(0)
            .and change { Jobs::CreateAvatarThumbnails.jobs.size }.by(0)
            .and change { Post.where(baked_version: nil).count }.by(1)
        end
      end
    end

    shared_examples "common remaps" do
      it "remaps when `base_url` changes" do
        Discourse.expects(:base_url).returns("http://localhost").at_least_once

        expect_remap(
          target_site_name: target_site_name,
          metadata: [source_site_type, base_url],
          from: "https://www.example.com/forum",
          to: "http://localhost"
        )
      end

      it "doesn't remap when `cdn_url` in `backup_metadata` is empty" do
        expect_no_remap(
          target_site_name: target_site_name,
          metadata: [source_site_type, no_cdn_url]
        )
      end

      it "remaps to new `cdn_url` when `cdn_url` changes to a different value" do
        Discourse.expects(:asset_host).returns("https://new-cdn.example.com").at_least_once

        expect_remaps(
          target_site_name: target_site_name,
          metadata: [source_site_type, cdn_url],
          remaps: [
            { from: "https://some-cdn.example.com/", to: "https://new-cdn.example.com/" },
            { from: "some-cdn.example.com", to: "new-cdn.example.com" }
          ]
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
            { from: "some-cdn.example.com", to: "example.com" }
          ]
        )
      end
    end

    shared_examples "remaps from local storage" do
      it "doesn't remap when `s3_base_url` in `backup_metadata` is empty" do
        expect_no_remap(
          target_site_name: target_site_name,
          metadata: [source_site_type, s3_base_url]
        )
      end

      it "doesn't remap when `s3_cdn_url` in `backup_metadata` is empty" do
        expect_no_remap(
          target_site_name: target_site_name,
          metadata: [source_site_type, s3_cdn_url]
        )
      end
    end

    context "currently stored locally" do
      before do
        SiteSetting.enable_s3_uploads = false
      end

      let!(:store_class) { FileStore::LocalStore }

      include_context "no uploads"
      include_context "restores uploads"

      context "remaps" do
        include_examples "without metadata"

        context "uploads previously stored locally" do
          let!(:s3_base_url) { { name: "s3_base_url", value: nil } }
          let!(:s3_cdn_url) { { name: "s3_cdn_url", value: nil } }

          context "from regular site" do
            let!(:source_site_type) { no_multisite }

            context "to regular site" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end

            context "to multisite", type: :multisite do
              let!(:target_site_type) { multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end
          end

          context "from multisite" do
            let!(:source_site_type) { multisite }

            context "to regular site" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end

            context "to multisite", type: :multisite do
              let!(:target_site_type) { multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end
          end
        end

        context "uploads previously stored on S3" do
          let!(:s3_base_url) { { name: "s3_base_url", value: "//old-bucket.s3-us-east-1.amazonaws.com" } }
          let!(:s3_cdn_url) { { name: "s3_cdn_url", value: "https://s3-cdn.example.com" } }

          shared_examples "regular site remaps from S3" do
            it "remaps when `s3_base_url` changes" do
              expect_remap(
                target_site_name: target_site_name,
                metadata: [no_multisite, s3_base_url],
                from: "//old-bucket.s3-us-east-1.amazonaws.com/",
                to: uploads_path(target_site_name)
              )
            end

            it "remaps when `s3_cdn_url` changes" do
              expect_remaps(
                target_site_name: target_site_name,
                metadata: [no_multisite, s3_cdn_url],
                remaps: [
                  { from: "https://s3-cdn.example.com/", to: "//#{target_hostname}#{uploads_path(target_site_name)}" },
                  { from: "s3-cdn.example.com", to: target_hostname }
                ]
              )
            end
          end

          shared_examples "multisite remaps from S3" do
            it "remaps when `s3_base_url` changes" do
              expect_remap(
                target_site_name: target_site_name,
                metadata: [source_db_name, multisite, s3_base_url],
                from: "//old-bucket.s3-us-east-1.amazonaws.com/",
                to: "/"
              )
            end

            it "remaps when `s3_cdn_url` changes" do
              expect_remaps(
                target_site_name: target_site_name,
                metadata: [source_db_name, multisite, s3_cdn_url],
                remaps: [
                  { from: "https://s3-cdn.example.com/", to: "//#{target_hostname}/" },
                  { from: "s3-cdn.example.com", to: target_hostname }
                ]
              )
            end
          end

          context "from regular site" do
            let!(:source_site_type) { no_multisite }

            context "to regular site" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "regular site remaps from S3"
            end

            context "to multisite", type: :multisite do
              let!(:target_site_type) { multisite }

              include_examples "common remaps"
              include_examples "regular site remaps from S3"
            end
          end

          context "from multisite" do
            let!(:source_site_type) { multisite }

            context "to regular site" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "multisite remaps from S3"
            end

            context "to multisite", type: :multisite do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "multisite remaps from S3"
            end
          end
        end
      end
    end

    context "currently stored on S3" do
      before do
        SiteSetting.s3_upload_bucket = "s3-upload-bucket"
        SiteSetting.s3_access_key_id = "s3-access-key-id"
        SiteSetting.s3_secret_access_key = "s3-secret-access-key"
        SiteSetting.enable_s3_uploads = true
      end

      let!(:store_class) { FileStore::S3Store }

      include_context "no uploads"
      include_context "restores uploads"

      context "remaps" do
        include_examples "without metadata"

        context "uploads previously stored locally" do
          let!(:s3_base_url) { { name: "s3_base_url", value: nil } }
          let!(:s3_cdn_url) { { name: "s3_cdn_url", value: nil } }

          context "from regular site" do
            let!(:source_site_type) { no_multisite }

            context "to regular site" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end

            context "to multisite", type: :multisite do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end
          end

          context "from multisite" do
            let!(:source_site_type) { multisite }

            context "to regular site" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end

            context "to multisite", type: :multisite do
              let!(:target_site_type) { multisite }

              include_examples "common remaps"
              include_examples "remaps from local storage"
            end
          end
        end

        context "uploads previously stored on S3" do
          let!(:s3_base_url) { { name: "s3_base_url", value: "//old-bucket.s3-us-east-1.amazonaws.com" } }
          let!(:s3_cdn_url) { { name: "s3_cdn_url", value: "https://s3-cdn.example.com" } }

          shared_examples "regular site remaps from S3" do
            it "remaps when `s3_base_url` changes" do
              expect_remap(
                target_site_name: target_site_name,
                metadata: [no_multisite, s3_base_url],
                from: "//old-bucket.s3-us-east-1.amazonaws.com/",
                to: uploads_path(target_site_name)
              )
            end

            it "remaps when `s3_cdn_url` changes" do
              SiteSetting::Upload.expects(:s3_cdn_url).returns("https://new-s3-cdn.example.com").at_least_once

              expect_remaps(
                target_site_name: target_site_name,
                metadata: [no_multisite, s3_cdn_url],
                remaps: [
                  { from: "https://s3-cdn.example.com/", to: "https://new-s3-cdn.example.com#{uploads_path(target_site_name)}" },
                  { from: "s3-cdn.example.com", to: "new-s3-cdn.example.com" }
                ]
              )
            end
          end

          shared_examples "multisite remaps from S3" do
            it "remaps when `s3_base_url` changes" do
              expect_remap(
                target_site_name: target_site_name,
                metadata: [source_db_name, multisite, s3_base_url],
                from: "//old-bucket.s3-us-east-1.amazonaws.com/",
                to: "/"
              )
            end

            context "when `s3_cdn_url` is configured" do
              it "remaps when `s3_cdn_url` changes" do
                SiteSetting::Upload.expects(:s3_cdn_url).returns("http://new-s3-cdn.example.com").at_least_once

                expect_remaps(
                  target_site_name: target_site_name,
                  metadata: [source_db_name, multisite, s3_cdn_url],
                  remaps: [
                    { from: "https://s3-cdn.example.com/", to: "//new-s3-cdn.example.com/" },
                    { from: "s3-cdn.example.com", to: "new-s3-cdn.example.com" }
                  ]
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
                    { from: "s3-cdn.example.com", to: target_hostname }
                  ]
                )
              end
            end
          end

          context "from regular site" do
            let!(:source_site_type) { no_multisite }

            context "to regular site" do
              let!(:target_site_name) { "default" }
              let!(:target_hostname) { "test.localhost" }

              include_examples "common remaps"
              include_examples "regular site remaps from S3"
            end

            context "to multisite", type: :multisite do
              let!(:target_site_name) { "second" }
              let!(:target_hostname) { "test2.localhost" }

              include_examples "common remaps"
              include_examples "regular site remaps from S3"
            end
          end

          context "from multisite" do
            let!(:source_site_type) { multisite }

            context "to regular site" do
              let!(:target_site_type) { no_multisite }

              include_examples "common remaps"
              include_examples "multisite remaps from S3"
            end

            context "to multisite", type: :multisite do
              let!(:target_site_type) { multisite }

              include_examples "common remaps"
              include_examples "multisite remaps from S3"
            end
          end
        end
      end
    end
  end

  it "raises an exception when the store doesn't support the copy_from method" do
    Discourse.stubs(:store).returns(Object.new)

    with_temp_uploads_directory do |directory|
      expect { subject.restore(directory) }.to raise_error(BackupRestore::UploadsRestoreError)
    end
  end

  it "raises an exception when there are multiple folders in the uploads directory" do
    with_temp_uploads_directory do |directory|
      FileUtils.mkdir_p(File.join(directory, "uploads", "foo"))
      expect { subject.restore(directory) }.to raise_error(BackupRestore::UploadsRestoreError)
    end
  end

  it "ignores 'PaxHeaders' and hidden directories within the uploads directory" do
    expect_remap(
      source_site_name: "xylan",
      target_site_name: "default",
      from: "/uploads/xylan/",
      to: uploads_path("default")
    ) do |directory|
      FileUtils.mkdir_p(File.join(directory, "uploads", "PaxHeaders.27134"))
      FileUtils.mkdir_p(File.join(directory, "uploads", ".hidden"))
    end
  end
end
