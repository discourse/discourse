# frozen_string_literal: true

RSpec.describe UploadRecovery do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:upload) do
    UploadCreator.new(file_from_fixtures("smallest.png"), "logo.png").create_for(user.id)
  end

  let(:upload2) do
    UploadCreator.new(file_from_fixtures("small.pdf", "pdf"), "some.pdf").create_for(user.id)
  end

  let(:post) do
    Fabricate(:post, raw: "![logo.png](#{upload.short_url})", user: user).tap(&:link_post_uploads)
  end

  let(:upload_recovery) { UploadRecovery.new }

  before do
    SiteSetting.authorized_extensions = "png|pdf"
    Jobs.run_immediately!
  end

  after do
    [upload, upload2].each do |u|
      next if u
      public_path = "#{Discourse.store.public_dir}#{u.url}"

      [public_path, public_path.sub("uploads", "uploads/tombstone")].each do |path|
        File.delete(path) if File.exist?(path)
      end
    end
  end

  describe "#recover" do
    describe "when given an invalid sha1" do
      it "does nothing" do
        upload_recovery.expects(:recover_from_local).never

        post.update!(raw: "![logo.png](upload://#{"a" * 28}.png)")

        upload_recovery.recover

        post.update!(
          raw: "<a href=#{"/uploads/test/original/3X/a/6%0A/#{upload.sha1}.png"}>test</a>",
        )

        upload_recovery.recover
      end
    end

    it "accepts a custom ActiveRecord relation" do
      post.update!(updated_at: 2.days.ago)
      upload.destroy!

      upload_recovery.expects(:recover_from_local).never
      upload_recovery.recover(Post.where("updated_at >= ?", 1.day.ago))
    end

    describe "for a missing attachment" do
      let(:post) { Fabricate(:post, raw: <<~SQL, user: user).tap(&:link_post_uploads) }
          <a class="attachment" href="#{upload2.url}">some.pdf</a>
          <a>blank</a>
          SQL

      it "recovers the attachment" do
        expect do upload2.destroy! end.to change { post.reload.uploads.count }.from(1).to(0)

        expect do upload_recovery.recover end.to change { post.reload.uploads.count }.from(0).to(1)

        expect(File.read(Discourse.store.path_for(post.uploads.first))).to eq(
          File.read(file_from_fixtures("small.pdf", "pdf")),
        )
      end
    end

    it "recovers uploads and attachments" do
      stub_request(:get, "http://test.localhost#{upload.url}").to_return(status: 200)

      expect do upload.destroy! end.to change { post.reload.uploads.count }.from(1).to(0)

      expect do upload_recovery.recover end.to change { post.reload.uploads.count }.from(0).to(1)

      expect(File.read(Discourse.store.path_for(post.uploads.first))).to eq(
        File.read(file_from_fixtures("smallest.png")),
      )
    end

    describe "S3 store" do
      before do
        setup_s3
        stub_s3_store
      end

      def stub_recovery_listing(tombstone_key)
        Discourse.store.s3_helper.s3_client.stub_responses(
          :list_objects_v2,
          [{ contents: [] }, { contents: [{ key: tombstone_key, size: 1 }] }],
        )
      end

      it "recovers the upload" do
        expect do upload.destroy! end.to change { post.reload.uploads.count }.from(1).to(0)

        original_key = Discourse.store.get_path_for_upload(upload)
        tombstone_key = original_key.sub("original", "tombstone/original")

        stub_recovery_listing(tombstone_key)

        Discourse
          .store
          .s3_helper
          .expects(:copy)
          .with(
            tombstone_key,
            original_key,
            options: {
              acl: FileStore::S3Store::CANNED_ACL_PUBLIC_READ,
            },
          )

        FileHelper.expects(:download).returns(file_from_fixtures("smallest.png"))
        stub_request(:get, upload.url).to_return(body: file_from_fixtures("smallest.png"))

        expect do upload_recovery.recover end.to change { post.reload.uploads.count }.from(0).to(1)
      end

      describe "when the upload exists but its file is missing" do
        it "recovers the file" do
          upload.verification_status = Upload.verification_statuses[:invalid_etag]
          upload.save!

          original_key = Discourse.store.get_path_for_upload(upload)
          tombstone_key = original_key.sub("original", "tombstone/original")

          stub_recovery_listing(tombstone_key)

          Discourse
            .store
            .s3_helper
            .expects(:copy)
            .with(
              tombstone_key,
              original_key,
              options: {
                acl: FileStore::S3Store::CANNED_ACL_PUBLIC_READ,
              },
            )

          expect do upload_recovery.recover end.to_not change {
            [post.reload.uploads.count, Upload.count]
          }
        end

        it "does not create a duplicate upload when secure uploads are enabled" do
          SiteSetting.secure_uploads = true
          upload.verification_status = Upload.verification_statuses[:invalid_etag]
          upload.save!

          original_key = Discourse.store.get_path_for_upload(upload)
          tombstone_key = original_key.sub("original", "tombstone/original")

          stub_recovery_listing(tombstone_key)
          Discourse
            .store
            .s3_helper
            .expects(:copy)
            .with(
              tombstone_key,
              original_key,
              options: {
                acl: FileStore::S3Store::CANNED_ACL_PUBLIC_READ,
              },
            )

          expect do upload_recovery.recover end.to_not change {
            [post.reload.uploads.count, Upload.count]
          }
        end
      end

      [false, true].each do |multisite|
        it "lists originals before tombstones with multisite=#{multisite}" do
          Rails.configuration.stubs(:multisite).returns(multisite)
          db = RailsMultisite::ConnectionManagement.current_db
          prefixes =
            if multisite
              ["uploads/#{db}/original", "uploads/tombstone/#{db}/original"]
            else
              %w[original tombstone/original]
            end
          client = Discourse.store.s3_helper.s3_client
          client.stub_responses(
            :list_objects_v2,
            prefixes.map { |prefix| { contents: [{ key: "#{prefix}/file.png", size: 1 }] } },
          )

          expect(upload_recovery.send(:s3_object_keys)).to eq(
            prefixes.map { |prefix| "#{prefix}/file.png" },
          )
          listings =
            client.api_requests.select { |request| request[:operation_name] == :list_objects_v2 }
          expect(listings.map { |request| request[:params][:prefix] }).to eq(prefixes)
        end
      end

      it "fails rather than recovering from a partial listing" do
        Discourse.store.s3_helper.s3_client.stub_responses(
          :list_objects_v2,
          [{ contents: [{ key: "original/file.png", size: 1 }] }, "AccessDenied"],
        )
        expect { upload_recovery.send(:s3_object_keys) }.to raise_error(
          Aws::S3::Errors::AccessDenied,
        )
      end
    end

    describe "image tag" do
      let(:post) { Fabricate(:post, raw: <<~SQL, user: user).tap(&:link_post_uploads) }
          <img src='#{upload.url}'>
          SQL

      it "recovers the upload" do
        stub_request(:get, "http://test.localhost#{upload.url}").to_return(status: 200)

        expect do upload.destroy! end.to change { post.reload.uploads.count }.from(1).to(0)

        expect do upload_recovery.recover end.to change { post.reload.uploads.count }.from(0).to(1)

        expect(File.read(Discourse.store.path_for(post.uploads.first))).to eq(
          File.read(file_from_fixtures("smallest.png")),
        )
      end
    end

    describe "image markdown" do
      let(:post) { Fabricate(:post, raw: <<~SQL, user: user).tap(&:link_post_uploads) }
          ![image](#{upload.url})
          SQL

      it "recovers the upload" do
        stub_request(:get, "http://test.localhost#{upload.url}").to_return(status: 200)

        expect do upload.destroy! end.to change { post.reload.uploads.count }.from(1).to(0)

        expect do upload_recovery.recover end.to change { post.reload.uploads.count }.from(0).to(1)

        expect(File.read(Discourse.store.path_for(post.uploads.first))).to eq(
          File.read(file_from_fixtures("smallest.png")),
        )
      end
    end

    describe "bbcode" do
      let(:post) { Fabricate(:post, raw: <<~SQL, user: user).tap(&:link_post_uploads) }
          [img]#{upload.url}[/img]
          SQL

      it "recovers the upload" do
        stub_request(:get, "http://test.localhost#{upload.url}").to_return(status: 200)

        expect do upload.destroy! end.to change { post.reload.uploads.count }.from(1).to(0)

        expect do upload_recovery.recover end.to change { post.reload.uploads.count }.from(0).to(1)

        expect(File.read(Discourse.store.path_for(post.uploads.first))).to eq(
          File.read(file_from_fixtures("smallest.png")),
        )
      end
    end
  end
end
