# frozen_string_literal: true

RSpec.describe "tasks/uploads" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
    SiteSetting.authorized_extensions += "|pdf"
  end

  describe "uploads:secure_upload_analyse_and_update" do
    let!(:uploads) { [multi_post_upload1, upload1, upload2, upload3] }
    let(:multi_post_upload1) { Fabricate(:upload_s3) }
    let(:upload1) { Fabricate(:upload_s3) }
    let(:upload2) { Fabricate(:upload_s3) }
    let(:upload3) { Fabricate(:upload_s3, original_filename: "test.pdf", extension: "pdf") }

    let!(:post1) { Fabricate(:post) }
    let!(:post2) { Fabricate(:post) }
    let!(:post3) { Fabricate(:post) }

    before do
      UploadReference.create(target: post1, upload: multi_post_upload1)
      UploadReference.create(target: post2, upload: multi_post_upload1)
      UploadReference.create(target: post2, upload: upload1)
      UploadReference.create(target: post3, upload: upload2)
      UploadReference.create(target: post3, upload: upload3)
    end

    def invoke_task
      capture_stdout { Rake::Task["uploads:secure_upload_analyse_and_update"].invoke }
    end

    context "when the store is internal" do
      it "does nothing; this is for external store only" do
        Upload.expects(:transaction).never
        expect { invoke_task }.to raise_error(SystemExit)
      end
    end

    context "when store is external" do
      before do
        setup_s3
        uploads.each { |upload| stub_upload(upload) }
      end

      context "when secure upload is enabled" do
        before { SiteSetting.secure_uploads = true }

        it "sets an access_control_post for each post upload, using the first linked post in the case of multiple links" do
          invoke_task
          expect(multi_post_upload1.reload.access_control_post).to eq(post1)
          expect(upload1.reload.access_control_post).to eq(post2)
          expect(upload2.reload.access_control_post).to eq(post3)
          expect(upload3.reload.access_control_post).to eq(post3)
        end

        it "sets everything attached to a post as secure and rebakes all those posts if login is required" do
          SiteSetting.login_required = true
          freeze_time

          post1.update_columns(baked_at: 1.week.ago)
          post2.update_columns(baked_at: 1.week.ago)
          post3.update_columns(baked_at: 1.week.ago)

          invoke_task

          expect(post1.reload.baked_at).not_to eq_time(1.week.ago)
          expect(post2.reload.baked_at).not_to eq_time(1.week.ago)
          expect(post3.reload.baked_at).not_to eq_time(1.week.ago)
          expect(upload2.reload.secure).to eq(true)
          expect(upload1.reload.secure).to eq(true)
          expect(upload3.reload.secure).to eq(true)
        end

        it "sets the uploads that are media and attachments in the read restricted topic category to secure" do
          post3.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))
          invoke_task
          expect(upload2.reload.secure).to eq(true)
          expect(upload1.reload.secure).to eq(false)
          expect(upload3.reload.secure).to eq(true)
        end

        it "sets the upload in the PM topic to secure" do
          post3.topic.update(archetype: "private_message", category: nil)
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
            post3.topic.update(archetype: "private_message", category: nil)
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
            UploadReference.create(target: post_for_upload, upload: upload_to_mark_not_secure)

            setup_s3
            uploads.each { |upload| stub_upload(upload) }
            stub_upload(upload_to_mark_not_secure)

            invoke_task
            expect(upload_to_mark_not_secure.reload.secure).to eq(false)
          end
        end
      end
    end
  end

  describe "uploads:disable_secure_uploads" do
    def invoke_task
      capture_stdout { Rake::Task["uploads:disable_secure_uploads"].invoke }
    end

    before do
      setup_s3
      uploads.each { |upload| stub_upload(upload) }

      SiteSetting.secure_uploads = true
      UploadReference.create(target: post1, upload: upload1)
      UploadReference.create(target: post1, upload: upload2)
      UploadReference.create(target: post2, upload: upload3)
      UploadReference.create(target: post2, upload: upload4)
    end

    let!(:uploads) { [upload1, upload2, upload3, upload4, upload5] }
    let(:post1) { Fabricate(:post) }
    let(:post2) { Fabricate(:post) }
    let(:upload1) { Fabricate(:upload_s3, secure: true, access_control_post: post1) }
    let(:upload2) { Fabricate(:upload_s3, secure: true, access_control_post: post1) }
    let(:upload3) { Fabricate(:upload_s3, secure: true, access_control_post: post2) }
    let(:upload4) { Fabricate(:upload_s3, secure: true, access_control_post: post2) }
    let(:upload5) { Fabricate(:upload_s3, secure: false) }

    it "disables the secure upload setting" do
      invoke_task
      expect(SiteSetting.secure_uploads).to eq(false)
    end

    it "updates all secure uploads to secure: false" do
      invoke_task
      [upload1, upload2, upload3, upload4].each { |upl| expect(upl.reload.secure).to eq(false) }
    end

    it "rebakes the associated posts" do
      freeze_time

      post1.update_columns(baked_at: 1.week.ago)
      post2.update_columns(baked_at: 1.week.ago)
      invoke_task

      expect(post1.reload.baked_at).not_to eq_time(1.week.ago)
      expect(post2.reload.baked_at).not_to eq_time(1.week.ago)
    end

    it "updates the affected ACLs via the SyncAclsForUploads job" do
      invoke_task
      expect(Jobs::SyncAclsForUploads.jobs.last["args"][0]["upload_ids"]).to match_array(
        [upload1.id, upload2.id, upload3.id, upload4.id],
      )
    end
  end

  describe "uploads:downsize" do
    def invoke_task
      capture_stdout { Rake::Task["uploads:downsize"].invoke }
    end

    before { STDIN.stubs(:beep) }

    fab!(:upload) { Fabricate(:image_upload, width: 200, height: 200) }

    it "corrects upload attributes" do
      upload.update!(thumbnail_height: 0)

      expect { invoke_task }.to change { upload.reload.thumbnail_height }.to(200)
    end

    it "updates attributes of uploads that are over the size limit" do
      upload.update!(thumbnail_height: 0)
      SiteSetting.max_image_size_kb = 0.001 # 1 byte

      expect { invoke_task }.to change { upload.reload.thumbnail_height }.to(200)
    end
  end
end
