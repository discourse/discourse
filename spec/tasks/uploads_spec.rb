# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "tasks/uploads" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
    SiteSetting.authorized_extensions += "|pdf"
  end

  describe "uploads:secure_upload_analyse_and_update" do
    let!(:uploads) do
      [
        multi_post_upload1,
        upload1,
        upload2,
        upload3
      ]
    end
    let(:multi_post_upload1) { Fabricate(:upload_s3) }
    let(:upload1) { Fabricate(:upload_s3) }
    let(:upload2) { Fabricate(:upload_s3) }
    let(:upload3) { Fabricate(:upload_s3, original_filename: 'test.pdf', extension: 'pdf') }

    let!(:post1) { Fabricate(:post) }
    let!(:post2) { Fabricate(:post) }
    let!(:post3) { Fabricate(:post) }

    before do
      PostUpload.create(post: post1, upload: multi_post_upload1)
      PostUpload.create(post: post2, upload: multi_post_upload1)
      PostUpload.create(post: post2, upload: upload1)
      PostUpload.create(post: post3, upload: upload2)
      PostUpload.create(post: post3, upload: upload3)
    end

    def invoke_task
      capture_stdout do
        Rake::Task['uploads:secure_upload_analyse_and_update'].invoke
      end
    end

    context "when the store is internal" do
      it "does nothing; this is for external store only" do
        Upload.expects(:transaction).never
        expect { invoke_task }.to raise_error(SystemExit)
      end
    end

    context "when store is external" do
      before do
        enable_s3_uploads(uploads)
      end

      context "when secure media is enabled" do
        before do
          SiteSetting.secure_media = true
        end

        it "sets an access_control_post for each post upload, using the first linked post in the case of multiple links" do
          invoke_task
          expect(multi_post_upload1.reload.access_control_post).to eq(post1)
          expect(upload1.reload.access_control_post).to eq(post2)
          expect(upload2.reload.access_control_post).to eq(post3)
          expect(upload3.reload.access_control_post).to eq(post3)
        end

        it "sets the uploads that are media and attachments in the read restricted topic category to secure" do
          post3.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))
          invoke_task
          expect(upload2.reload.secure).to eq(true)
          expect(upload1.reload.secure).to eq(false)
          expect(upload3.reload.secure).to eq(true)
        end

        it "sets the upload in the PM topic to secure" do
          post3.topic.update(archetype: 'private_message', category: nil)
          invoke_task
          expect(upload2.reload.secure).to eq(true)
          expect(upload1.reload.secure).to eq(false)
        end

        it "rebakes the posts attached for uploads that change secure status" do
          post3.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))
          freeze_time

          post1.update_columns(baked_at: 1.week.ago)
          post2.update_columns(baked_at: 1.week.ago)
          post3.update_columns(baked_at: 1.week.ago)

          invoke_task

          expect(post1.reload.baked_at).to eq_time(1.week.ago)
          expect(post2.reload.baked_at).to eq_time(1.week.ago)
          expect(post3.reload.baked_at).not_to eq_time(1.week.ago)
        end

        context "for an upload that is already secure and does not need to change" do
          before do
            post3.topic.update(archetype: 'private_message', category: nil)
            upload2.update(access_control_post: post3)
            upload2.update_secure_status
            upload3.update(access_control_post: post3)
            upload3.update_secure_status
          end

          it "does not rebake the associated post" do
            freeze_time

            post3.update_columns(baked_at: 1.week.ago)
            invoke_task

            expect(post3.reload.baked_at).to eq_time(1.week.ago)
          end

          it "does not attempt to update the acl" do
            Discourse.store.expects(:update_upload_ACL).with(upload2).never
            invoke_task
          end
        end

        context "for an upload that is already secure and is changing to not secure" do
          it "changes the upload to not secure and updates the ACL" do
            upload_to_mark_not_secure = Fabricate(:upload_s3, secure: true)
            post_for_upload = Fabricate(:post)
            PostUpload.create(post: post_for_upload, upload: upload_to_mark_not_secure)
            enable_s3_uploads(uploads.concat([upload_to_mark_not_secure]))
            invoke_task
            expect(upload_to_mark_not_secure.reload.secure).to eq(false)
          end
        end
      end
    end
  end

  describe "uploads:batch_migrate_from_s3" do
    let!(:uploads) do
      [
        upload1,
        upload2,
      ]
    end

    let(:upload1) { Fabricate(:upload_s3) }
    let(:upload2) { Fabricate(:upload_s3) }

    let!(:url1) { "upload://#{upload1.base62_sha1}.jpg" }
    let!(:url2) { "upload://#{upload2.base62_sha1}.jpg" }

    let(:post1) { Fabricate(:post, raw: "[foo](#{url1})") }
    let(:post2) { Fabricate(:post, raw: "[foo](#{url2})") }

    before do
      global_setting :s3_bucket, 'file-uploads/folder'
      global_setting :s3_region, 'us-east-1'
      enable_s3_uploads(uploads)
      upload1.url = "//#{SiteSetting.s3_upload_bucket}.amazonaws.com/original/1X/#{upload1.base62_sha1}.png"
      upload1.save!
      upload2.url = "//#{SiteSetting.s3_upload_bucket}.amazonaws.com/original/1X/#{upload2.base62_sha1}.png"
      upload2.save!

      PostUpload.create(post: post1, upload: upload1)
      PostUpload.create(post: post2, upload: upload2)
      SiteSetting.enable_s3_uploads = false
    end

    def invoke_task
      capture_stdout do
        Rake::Task['uploads:batch_migrate_from_s3'].invoke('1')
      end
    end

    it "applies the limit" do
      FileHelper.stubs(:download).returns(file_from_fixtures("logo.png")).once()

      freeze_time

      post1.update_columns(baked_at: 1.week.ago)
      post2.update_columns(baked_at: 1.week.ago)
      invoke_task

      expect(post1.reload.baked_at).not_to eq_time(1.week.ago)
      expect(post2.reload.baked_at).to eq_time(1.week.ago)
    end

  end

  describe "uploads:migrate_from_s3" do
    let!(:uploads) do
      [
        upload1,
        upload2,
      ]
    end

    let(:upload1) { Fabricate(:upload_s3) }
    let(:upload2) { Fabricate(:upload_s3) }

    let!(:url1) { "upload://#{upload1.base62_sha1}.jpg" }
    let!(:url2) { "upload://#{upload2.base62_sha1}.jpg" }

    let(:post1) { Fabricate(:post, raw: "[foo](#{url1})") }
    let(:post2) { Fabricate(:post, raw: "[foo](#{url2})") }

    before do
      global_setting :s3_bucket, 'file-uploads/folder'
      global_setting :s3_region, 'us-east-1'
      enable_s3_uploads(uploads)
      upload1.url = "//#{SiteSetting.s3_upload_bucket}.amazonaws.com/original/1X/#{upload1.base62_sha1}.png"
      upload1.save!
      upload2.url = "//#{SiteSetting.s3_upload_bucket}.amazonaws.com/original/1X/#{upload2.base62_sha1}.png"
      upload2.save!

      PostUpload.create(post: post1, upload: upload1)
      PostUpload.create(post: post2, upload: upload2)
      SiteSetting.enable_s3_uploads = false
    end

    def invoke_task
      capture_stdout do
        Rake::Task['uploads:migrate_from_s3'].invoke
      end
    end

    it "fails if s3 uploads are still enabled" do
      SiteSetting.enable_s3_uploads = true
      expect { invoke_task }.to raise_error(SystemExit)
    end

    it "does not apply a limit" do
      FileHelper.stubs(:download).with("http:#{upload1.url}", max_file_size: 4194304, tmp_file_name: "from_s3", follow_redirect: true).returns(file_from_fixtures("logo.png")).once()
      FileHelper.stubs(:download).with("http:#{upload2.url}", max_file_size: 4194304, tmp_file_name: "from_s3", follow_redirect: true).returns(file_from_fixtures("logo.png")).once()

      freeze_time

      post1.update_columns(baked_at: 1.week.ago)
      post2.update_columns(baked_at: 1.week.ago)
      invoke_task

      expect(post1.reload.baked_at).not_to eq_time(1.week.ago)
      expect(post2.reload.baked_at).not_to eq_time(1.week.ago)
    end
  end

  describe "uploads:disable_secure_media" do
    def invoke_task
      capture_stdout do
        Rake::Task['uploads:disable_secure_media'].invoke
      end
    end

    before do
      enable_s3_uploads(uploads)
      SiteSetting.secure_media = true
      PostUpload.create(post: post1, upload: upload1)
      PostUpload.create(post: post1, upload: upload2)
      PostUpload.create(post: post2, upload: upload3)
      PostUpload.create(post: post2, upload: upload4)
    end

    let!(:uploads) do
      [
        upload1, upload2, upload3, upload4, upload5
      ]
    end
    let(:post1) { Fabricate(:post) }
    let(:post2) { Fabricate(:post) }
    let(:upload1) { Fabricate(:upload_s3, secure: true, access_control_post: post1) }
    let(:upload2) { Fabricate(:upload_s3, secure: true, access_control_post: post1) }
    let(:upload3) { Fabricate(:upload_s3, secure: true, access_control_post: post2) }
    let(:upload4) { Fabricate(:upload_s3, secure: true, access_control_post: post2) }
    let(:upload5) { Fabricate(:upload_s3, secure: false) }

    it "disables the secure media setting" do
      invoke_task
      expect(SiteSetting.secure_media).to eq(false)
    end

    it "updates all secure uploads to secure: false" do
      invoke_task
      [upload1, upload2, upload3, upload4].each do |upl|
        expect(upl.reload.secure).to eq(false)
      end
    end

    it "rebakes the associated posts" do
      freeze_time

      post1.update_columns(baked_at: 1.week.ago)
      post2.update_columns(baked_at: 1.week.ago)
      invoke_task

      expect(post1.reload.baked_at).not_to eq_time(1.week.ago)
      expect(post2.reload.baked_at).not_to eq_time(1.week.ago)
    end

    it "updates the affected ACLs" do
      FileStore::S3Store.any_instance.expects(:update_upload_ACL).times(4)
      invoke_task
    end
  end

  def enable_s3_uploads(uploads)
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_upload_bucket = "s3-upload-bucket"
    SiteSetting.s3_access_key_id = "some key"
    SiteSetting.s3_secret_access_key = "some secrets3_region key"

    stub_request(:head, "https://#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com/")

    uploads.each do |upload|
      stub_request(
        :put,
        "https://#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com/original/1X/#{upload.sha1}.#{upload.extension}?acl"
      )
    end
  end
end
