require 'rails_helper'

describe Jobs::PendingFlagsReminder do
  context "notify_about_flags_after is 0" do
    before { SiteSetting.stubs(:notify_about_flags_after).returns(0) }

    it "never emails" do
      PostAction.stubs(:flagged_posts_count).returns(1)
      Email::Sender.any_instance.expects(:send).never
      described_class.new.execute({})
    end
  end

  context "notify_about_flags_after is 48" do
    before { SiteSetting.stubs(:notify_about_flags_after).returns(48) }

    it "doesn't send message when flags are less than 48 hours old" do
      Fabricate(:flag, created_at: 47.hours.ago)
      PostAction.stubs(:flagged_posts_count).returns(1)
      PostCreator.expects(:create).never
      described_class.new.execute({})
    end

    it "sends message when there is a flag older than 48 hours" do
      Fabricate(:flag, created_at: 49.hours.ago)
      PostAction.stubs(:flagged_posts_count).returns(1)
      PostCreator.expects(:create).once.returns(true)
      described_class.new.execute({})
    end
  end
end
