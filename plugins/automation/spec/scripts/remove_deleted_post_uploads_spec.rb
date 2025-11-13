# frozen_string_literal: true

describe "RemoveDeletedPostUploads" do
  fab!(:topic)
  fab!(:upload)

  fab!(:filename) { "small.pdf" }
  fab!(:file) { file_from_fixtures(filename, "pdf") }
  fab!(:file_upload) do
    UploadCreator.new(file, filename, { skip_validations: true }).create_for(
      Discourse.system_user.id,
    )
  end
  let!(:raw) do
    "Hey it is a regular post with a link to [Discourse](https://www.discourse.org) and a #{upload.to_markdown} #{file_upload.to_markdown}"
  end

  let!(:post) { Fabricate(:post, topic: topic, raw: raw) }
  let!(:deleted_post) { Fabricate(:post, topic: topic, raw: raw, deleted_at: 1.month.ago) }

  let!(:upload_reference) { Fabricate(:upload_reference, upload: upload, target: post) }
  let!(:deleted_upload_reference) do
    Fabricate(:upload_reference, upload: upload, target: deleted_post)
  end

  let!(:file_upload_reference) { Fabricate(:upload_reference, upload: file_upload, target: post) }
  let!(:deleted_file_upload_reference) do
    Fabricate(:upload_reference, upload: file_upload, target: deleted_post)
  end

  before { SiteSetting.discourse_automation_enabled = true }

  context "when using recurring trigger" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scripts::REMOVE_DELETED_POST_UPLOADS,
        trigger: DiscourseAutomation::Triggers::RECURRING,
      )
    end

    it "removes uploads from deleted posts" do
      expect {
        automation.trigger!
        deleted_post.reload
      }.to change { deleted_post.raw }.from(raw).to(
        "Hey it is a regular post with a link to [Discourse](https://www.discourse.org) and a",
      )

      expect(post.raw).to eq(raw)
    end

    it "adds a timestamp to the custom field uploads_deleted_at" do
      expect {
        automation.trigger!
        deleted_post.reload
      }.to change { deleted_post.custom_fields["uploads_deleted_at"] }.from(nil)

      expect(post.custom_fields["uploads_deleted_at"]).to be_nil
    end

    context "with clean_up_uploads job" do
      fab!(:old_upload) { Fabricate(:upload, created_at: 2.days.ago) }
      let!(:old_post_raw) do
        "Hey it is a regular post with a link to [Discourse](https://www.discourse.org) and a #{old_upload.to_markdown}"
      end

      let!(:old_post) { Fabricate(:post, topic: topic, raw: old_post_raw, deleted_at: 1.month.ago) }
      let!(:old_upload_reference) do
        Fabricate(:upload_reference, upload: old_upload, target: old_post)
      end

      before do
        SiteSetting.clean_up_uploads = true
        SiteSetting.clean_orphan_uploads_grace_period_hours = 1
      end

      it "allows uploads to be deleted" do
        automation.trigger!
        old_post.reload

        expect { Jobs::CleanUpUploads.new.execute(nil) }.to change {
          Upload.exists?(old_upload.id)
        }.from(true).to(false)

        expect(UploadReference.exists?(old_upload_reference.id)).to be_falsey
        expect(old_post.raw).to eq(
          "Hey it is a regular post with a link to [Discourse](https://www.discourse.org) and a",
        )
      end

      it "requires automation to remove upload references first" do
        old_post.reload

        expect { Jobs::CleanUpUploads.new.execute(nil) }.to_not change {
          Upload.exists?(old_upload.id)
        }.from(true)

        expect(UploadReference.exists?(old_upload_reference.id)).to be_truthy
      end
    end
  end

  context "when using point_in_time trigger" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scripts::REMOVE_DELETED_POST_UPLOADS,
        trigger: DiscourseAutomation::Triggers::POINT_IN_TIME,
      )
    end

    before do
      automation.upsert_field!(
        "execute_at",
        "date_time",
        { value: 3.hours.from_now },
        target: "trigger",
      )
    end

    it "removes uploads from deleted posts" do
      freeze_time 6.hours.from_now do
        expect {
          Jobs::DiscourseAutomation::Tracker.new.execute
          deleted_post.reload
        }.to change { deleted_post.raw }.from(raw).to(
          "Hey it is a regular post with a link to [Discourse](https://www.discourse.org) and a",
        )

        expect(post.raw).to eq(raw)
      end
    end

    it "adds a timestamp to the custom field uploads_deleted_at" do
      expect {
        automation.trigger!
        deleted_post.reload
      }.to change { deleted_post.custom_fields["uploads_deleted_at"] }.from(nil)

      expect(post.custom_fields["uploads_deleted_at"]).to be_nil
    end
  end
end
