# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "tasks/uploads" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
    disable_puts_stdout
  end

  describe "uploads:ensure_correct_acl" do
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

    let!(:post1) { Fabricate(:post) }
    let!(:post2) { Fabricate(:post) }
    let!(:post3) { Fabricate(:post) }

    before do
      PostUpload.create(post: post1, upload: multi_post_upload1)
      PostUpload.create(post: post2, upload: multi_post_upload1)
      PostUpload.create(post: post2, upload: upload1)
      PostUpload.create(post: post3, upload: upload2)
    end

    def invoke_task
      Rake::Task['uploads:ensure_correct_acl'].invoke
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
        end

        it "sets the upload in the read restricted topic category to secure" do
          post3.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))
          invoke_task
          expect(upload2.reload.secure).to eq(true)
          expect(upload1.reload.secure).to eq(false)
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
