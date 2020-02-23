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
        upload2
      ]
    end
    let(:multi_post_upload1) { Fabricate(:upload_s3) }
    let(:upload1) { Fabricate(:upload_s3) }
    let(:upload2) { Fabricate(:upload_s3) }
    let(:upload3) { Fabricate(:upload_s3, original_filename: 'test.pdf') }

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
        invoke_task
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

        it "sets the upload in the read restricted topic category to secure" do
          post3.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))
          invoke_task
          expect(upload2.reload.secure).to eq(true)
          expect(upload1.reload.secure).to eq(false)
          expect(upload3.reload.secure).to eq(false)
        end

        it "sets the upload in the PM topic to secure" do
          post3.topic.update(archetype: 'private_message', category: nil)
          invoke_task
          expect(upload2.reload.secure).to eq(true)
          expect(upload1.reload.secure).to eq(false)
        end

        it "rebakes the posts attached" do
          post1_baked = post1.baked_at
          post2_baked = post2.baked_at
          post3_baked = post3.baked_at

          invoke_task

          expect(post1.reload.baked_at).not_to eq(post1_baked)
          expect(post2.reload.baked_at).not_to eq(post2_baked)
          expect(post3.reload.baked_at).not_to eq(post3_baked)
        end

        context "for an upload that is already secure and does not need to change" do
          before do
            post3.topic.update(archetype: 'private_message', category: nil)
            upload2.update(access_control_post: post3)
            upload2.update_secure_status
          end

          it "does not rebake the associated post" do
            post3_baked = post3.baked_at.to_s
            invoke_task
            expect(post3.reload.baked_at.to_s).to eq(post3_baked)
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
