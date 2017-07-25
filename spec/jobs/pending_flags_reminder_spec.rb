require 'rails_helper'

describe Jobs::PendingFlagsReminder do
  context "notify_about_flags_after is 0" do
    before { SiteSetting.notify_about_flags_after = 0 }

    it "never notifies" do
      PostAction.stubs(:flagged_posts_count).returns(1)
      PostCreator.expects(:create).never
      described_class.new.execute({})
    end
  end

  context "notify_about_flags_after is 48" do
    before do
      SiteSetting.notify_about_flags_after = 48
      $redis.del described_class.last_notified_key
    end

    after do
      $redis.del described_class.last_notified_key
    end

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

    it "doesn't send a message if there are no new flags older than 48 hours old" do
      old_flag = Fabricate(:flag, created_at: 50.hours.ago)
      new_flag = Fabricate(:flag, created_at: 47.hours.ago)
      PostAction.stubs(:flagged_posts_count).returns(2)
      job = described_class.new
      job.last_notified_id = old_flag.id
      PostCreator.expects(:create).never
      job.execute({})
      expect(job.last_notified_id).to eq(old_flag.id)
    end
  end
end
