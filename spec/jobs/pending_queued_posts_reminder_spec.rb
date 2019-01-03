require "rails_helper"

describe Jobs::PendingQueuedPostReminder do
  let(:job) { described_class.new }

  context "notify_about_queued_posts_after is 0" do
    before { SiteSetting.notify_about_queued_posts_after = 0 }

    it "never emails" do
      described_class.any_instance.expects(:should_notify_ids).never
      expect {
        job.execute({})
      }.to_not change { Post.count }
    end
  end

  context "notify_about_queued_posts_after is 24" do
    before do
      SiteSetting.notify_about_queued_posts_after = 24
    end

    context "when we haven't been notified in a while" do

      before do
        job.last_notified_id = nil
      end

      it "doesn't create system message if there are no queued posts" do
        expect {
          job.execute({})
        }.to_not change { Post.count }
      end

      it "creates system message if there are new queued posts" do
        Fabricate(:reviewable_queued_post, created_at: 48.hours.ago)
        Fabricate(:reviewable_queued_post, created_at: 45.hours.ago)
        expect { job.execute({}) }.to change { Post.count }.by(1)
        expect(Topic.where(
          subtype: TopicSubtype.system_message,
          title: I18n.t('system_messages.queued_posts_reminder.subject_template', count: 2)
        ).exists?).to eq(true)
      end
    end

    it "doesn't create system message again about the same posts" do
      reviewable = Fabricate(:reviewable_queued_post, created_at: 48.hours.ago)
      job.last_notified_id = reviewable.id
      expect { described_class.new.execute({}) }.to_not change { Post.count }
    end
  end
end
