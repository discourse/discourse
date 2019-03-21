require 'rails_helper'

describe Jobs::PendingFlagsReminder do
  context 'notify_about_flags_after is 0' do
    before { SiteSetting.notify_about_flags_after = 0 }

    it 'never notifies' do
      Fabricate(:flag, created_at: 50.hours.ago)
      PostCreator.expects(:create).never
      described_class.new.execute({})
    end
  end

  context 'notify_about_flags_after is 48' do
    before do
      SiteSetting.notify_about_flags_after = 48
      $redis.del described_class.last_notified_key
    end

    after { $redis.del described_class.last_notified_key }

    it "doesn't send message when flags are less than 48 hours old" do
      Fabricate(:flag, created_at: 47.hours.ago)
      PostCreator.expects(:create).never
      described_class.new.execute({})
    end

    it "doesn't send a message if there are no new flags older than 48 hours old" do
      old_flag = Fabricate(:flag, created_at: 50.hours.ago)
      Fabricate(:flag, created_at: 47.hours.ago)
      job = described_class.new
      job.last_notified_id = old_flag.id
      PostCreator.expects(:create).never
      job.execute({})
      expect(job.last_notified_id).to eq(old_flag.id)
    end

    it 'sends message when there is a flag older than 48 hours' do
      Fabricate(:flag, created_at: 49.hours.ago)
      PostCreator.expects(:create).once.returns(true)
      described_class.new.execute({})
    end

    context 'min_flags_staff_visibility' do
      it "doesn't send a message when min_flags_staff_visibility is not met" do
        SiteSetting.min_flags_staff_visibility = 2
        Fabricate(:flag, created_at: 49.hours.ago)
        Fabricate(:flag, created_at: 51.hours.ago)
        PostCreator.expects(:create).never
        described_class.new.execute({})
      end

      it "doesn't send a message when min_flags_staff_visibility is met on new flags but not old" do
        SiteSetting.min_flags_staff_visibility = 2
        flag = Fabricate(:flag, created_at: 24.hours.ago)
        Fabricate(:flag, post: flag.post, created_at: 49.hours.ago)
        Fabricate(:flag, created_at: 51.hours.ago)
        PostCreator.expects(:create).never
        described_class.new.execute({})
      end

      it 'sends a message when min_flags_staff_visibility is met' do
        SiteSetting.min_flags_staff_visibility = 2
        f = Fabricate(:flag, created_at: 49.hours.ago)
        Fabricate(:flag, post: f.post, created_at: 51.hours.ago)
        PostCreator.expects(:create).once.returns(true)
        described_class.new.execute({})
      end
    end
  end
end
