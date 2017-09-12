require "rails_helper"

describe Jobs::PendingQueuedPostReminder do
  context "notify_about_queued_posts_after is 0" do
    before { SiteSetting.notify_about_queued_posts_after = 0 }

    it "never emails" do
      described_class.any_instance.expects(:should_notify_ids).never
      expect {
        described_class.new.execute({})
      }.to_not change { Post.count }
    end
  end

  context "notify_about_queued_posts_after is 24" do
    before do
      SiteSetting.notify_about_queued_posts_after = 24
    end

    it "doesn't create system message if there are no queued posts" do
      described_class.any_instance.stubs(:should_notify_ids).returns([])
      described_class.any_instance.stubs(:last_notified_id).returns(nil)
      expect {
        described_class.new.execute({})
      }.to_not change { Post.count }
    end

    it "creates system message if there are new queued posts" do
      described_class.any_instance.stubs(:should_notify_ids).returns([1, 2])
      described_class.any_instance.stubs(:last_notified_id).returns(nil)
      expect {
        described_class.new.execute({})
      }.to change { Post.count }.by(1)
      expect(Topic.where(
        subtype: TopicSubtype.system_message,
        title: I18n.t('system_messages.queued_posts_reminder.subject_template', count: 2)
      ).exists?).to eq(true)
    end

    it "doesn't create system message again about the same posts" do
      described_class.any_instance.stubs(:should_notify_ids).returns([2])
      described_class.any_instance.stubs(:last_notified_id).returns(2)
      expect {
        described_class.new.execute({})
      }.to_not change { Post.count }
    end
  end
end
