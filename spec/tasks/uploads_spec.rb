# frozen_string_literal: true

RSpec.describe "tasks/uploads" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
    SiteSetting.authorized_extensions += "|pdf"
    STDIN.stubs(:gets).returns("y\n")
  end

  describe "uploads:secure_upload_analyse_and_update" do
    let!(:uploads) { [multi_post_upload_1, upload_1, upload_2, upload_3] }
    let(:multi_post_upload_1) { Fabricate(:upload_s3) }
    let(:upload_1) { Fabricate(:upload_s3) }
    let(:upload_2) { Fabricate(:upload_s3) }
    let(:upload_3) { Fabricate(:upload_s3, original_filename: "test.pdf", extension: "pdf") }

    let!(:post_1) { Fabricate(:post) }
    let!(:post_2) { Fabricate(:post) }
    let!(:post_3) { Fabricate(:post) }

    before do
      UploadReference.create(target: post_1, upload: multi_post_upload_1)
      UploadReference.create(target: post_2, upload: multi_post_upload_1)
      UploadReference.create(target: post_2, upload: upload_1)
      UploadReference.create(target: post_3, upload: upload_2)
      UploadReference.create(target: post_3, upload: upload_3)
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
          expect(multi_post_upload_1.reload.access_control_post).to eq(post_1)
          expect(upload_1.reload.access_control_post).to eq(post_2)
          expect(upload_2.reload.access_control_post).to eq(post_3)
          expect(upload_3.reload.access_control_post).to eq(post_3)
        end

        context "when login_required" do
          before { SiteSetting.login_required = true }

          after do
            if File.exist?("secure_upload_analyse_and_update_posts_for_rebake.json")
              File.delete("secure_upload_analyse_and_update_posts_for_rebake.json")
            end
          end

          it "sets everything attached to a post as secure" do
            invoke_task

            expect(upload_2.reload.secure).to eq(true)
            expect(upload_1.reload.secure).to eq(true)
            expect(upload_3.reload.secure).to eq(true)
          end

          it "writes a file with the post IDs to rebake" do
            invoke_task

            expect(File.exist?("secure_upload_analyse_and_update_posts_for_rebake.json")).to eq(
              true,
            )
            expect(
              JSON.parse(File.read("secure_upload_analyse_and_update_posts_for_rebake.json")),
            ).to eq({ "post_ids" => [post_1.id, post_2.id, post_3.id] })
          end

          it "sets the baked_version to NULL for affected posts" do
            invoke_task

            expect(post_1.reload.baked_version).to eq(nil)
            expect(post_2.reload.baked_version).to eq(nil)
            expect(post_3.reload.baked_version).to eq(nil)
          end

          context "when secure_uploads_pm_only" do
            before { SiteSetting.secure_uploads_pm_only = true }

            it "only sets everything attached to a private message post as secure and rebakes all those posts" do
              post_3.topic.update(archetype: "private_message", category: nil)

              invoke_task

              expect(post_1.reload.baked_version).not_to eq(nil)
              expect(post_2.reload.baked_version).not_to eq(nil)
              expect(post_3.reload.baked_version).to eq(nil)
              expect(upload_1.reload.secure).to eq(false)
              expect(upload_2.reload.secure).to eq(true)
              expect(upload_3.reload.secure).to eq(true)
            end
          end
        end

        it "sets the uploads that are media and attachments in the read restricted topic category to secure" do
          post_3.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))
          invoke_task
          expect(upload_2.reload.secure).to eq(true)
          expect(upload_1.reload.secure).to eq(false)
          expect(upload_3.reload.secure).to eq(true)
        end

        it "sets the upload in the PM topic to secure" do
          post_3.topic.update(archetype: "private_message", category: nil)
          invoke_task
          expect(upload_2.reload.secure).to eq(true)
          expect(upload_1.reload.secure).to eq(false)
        end

        it "sets the baked_version version to NULL for the posts attached for uploads that change secure status" do
          post_3.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))

          invoke_task

          expect(post_1.reload.baked_version).not_to eq(nil)
          expect(post_2.reload.baked_version).not_to eq(nil)
          expect(post_3.reload.baked_version).to eq(nil)
        end

        context "for an upload that is already secure and does not need to change" do
          before do
            post_3.topic.update(archetype: "private_message", category: nil)
            upload_2.update(access_control_post: post_3)
            upload_2.update_secure_status
            upload_3.update(access_control_post: post_3)
            upload_3.update_secure_status
          end

          it "does not rebake the associated post" do
            freeze_time

            post_3.update_columns(baked_at: 1.week.ago)
            invoke_task

            expect(post_3.reload.baked_at).to eq_time(1.week.ago)
          end

          it "does not attempt to update the acl" do
            FileStore::S3Store.any_instance.expects(:update_upload_ACL).with(upload_2).never
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
      UploadReference.create(target: post_1, upload: upload_1)
      UploadReference.create(target: post_1, upload: upload_2)
      UploadReference.create(target: post_2, upload: upload_3)
      UploadReference.create(target: post_2, upload: upload4)
    end

    after do
      if File.exist?("secure_upload_analyse_and_update_posts_for_rebake.json")
        File.delete("secure_upload_analyse_and_update_posts_for_rebake.json")
      end
    end

    let!(:uploads) { [upload_1, upload_2, upload_3, upload4, upload5] }
    let(:post_1) { Fabricate(:post) }
    let(:post_2) { Fabricate(:post) }
    let(:upload_1) { Fabricate(:upload_s3, secure: true, access_control_post: post_1) }
    let(:upload_2) { Fabricate(:upload_s3, secure: true, access_control_post: post_1) }
    let(:upload_3) { Fabricate(:upload_s3, secure: true, access_control_post: post_2) }
    let(:upload4) { Fabricate(:upload_s3, secure: true, access_control_post: post_2) }
    let(:upload5) { Fabricate(:upload_s3, secure: false) }

    it "disables the secure upload setting" do
      invoke_task
      expect(SiteSetting.secure_uploads).to eq(false)
    end

    it "updates all secure uploads to secure: false" do
      invoke_task
      [upload_1, upload_2, upload_3, upload4].each { |upl| expect(upl.reload.secure).to eq(false) }
    end

    it "sets the baked_version to NULL for affected posts" do
      invoke_task

      expect(post_1.reload.baked_version).to eq(nil)
      expect(post_2.reload.baked_version).to eq(nil)
    end

    it "writes a file with the post IDs to rebake" do
      invoke_task

      expect(File.exist?("secure_upload_analyse_and_update_posts_for_rebake.json")).to eq(true)
      expect(JSON.parse(File.read("secure_upload_analyse_and_update_posts_for_rebake.json"))).to eq(
        { "post_ids" => [post_1.id, post_2.id] },
      )
    end

    it "updates the affected ACLs via the SyncAclsForUploads job" do
      invoke_task
      expect(Jobs::SyncAclsForUploads.jobs.last["args"][0]["upload_ids"]).to match_array(
        [upload_1.id, upload_2.id, upload_3.id, upload4.id],
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
      SiteSetting.max_image_size_kb = 1

      expect { invoke_task }.to change { upload.reload.thumbnail_height }.to(200)
    end
  end
end
