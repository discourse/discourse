require "spec_helper"

describe Jobs::PendingQueuedPostReminder do
  context "notify_about_queued_posts_after is 0" do
    before { SiteSetting.stubs(:notify_about_queued_posts_after).returns(0) }

    it "never emails" do
      described_class.any_instance.expects(:should_notify_ids).never
      Email::Sender.any_instance.expects(:send).never
      described_class.new.execute({})
    end
  end

  context "notify_about_queued_posts_after is 24" do
    before { SiteSetting.stubs(:notify_about_queued_posts_after).returns(24) }

    it "doesn't email if there are no queued posts" do
      described_class.any_instance.stubs(:should_notify_ids).returns([])
      described_class.any_instance.stubs(:last_notified_id).returns(nil)
      Email::Sender.any_instance.expects(:send).never
      described_class.new.execute({})
    end

    it "emails if there are new queued posts" do
      described_class.any_instance.stubs(:should_notify_ids).returns([1,2])
      described_class.any_instance.stubs(:last_notified_id).returns(nil)
      Email::Sender.any_instance.expects(:send).once
      described_class.new.execute({})
    end

    it "doesn't email again about the same posts" do
      described_class.any_instance.stubs(:should_notify_ids).returns([2])
      described_class.any_instance.stubs(:last_notified_id).returns(2)
      Email::Sender.any_instance.expects(:send).never
      described_class.new.execute({})
    end
  end
end
