# frozen_string_literal: true

require 'rails_helper'

describe Jobs::PendingReviewablesReminder do
  let(:job) { described_class.new }

  def create_flag(created_at)
    PostActionCreator.create(Fabricate(:user), Fabricate(:post), :spam, created_at: created_at).reviewable
  end

  def execute
    job.tap { job.execute({}) }
  end

  it "doesn't notify when there are no flags" do
    expect(execute.sent_reminder).to eq(false)
  end

  context "notify_about_flags_after is 0" do
    before { SiteSetting.notify_about_flags_after = 0 }

    it "never notifies" do
      create_flag(50.hours.ago)
      expect(execute.sent_reminder).to eq(false)
    end
  end

  context "notify_about_flags_after is 48" do
    before do
      SiteSetting.notify_about_flags_after = 48
      described_class.clear_key
    end

    after do
      described_class.clear_key
    end

    it "doesn't send message when flags are less than 48 hours old" do
      create_flag(47.hours.ago)
      expect(execute.sent_reminder).to eq(false)
    end

    it "doesn't send a message if there are no new flags older than 48 hours old" do
      old_reviewable = create_flag(50.hours.ago)
      create_flag(47.hours.ago)

      described_class.last_notified_id = old_reviewable.id
      execute
      expect(job.sent_reminder).to eq(false)
      expect(described_class.last_notified_id).to eq(old_reviewable.id)
    end

    it "sends message when there is a flag older than 48 hours" do
      create_flag(49.hours.ago)
      expect(execute.sent_reminder).to eq(true)
    end

    context "reviewable_default_visibility" do
      before do
        create_flag(49.hours.ago)
        create_flag(51.hours.ago)
      end

      it "doesn't send a message when `reviewable_default_visibility` is not met" do
        Reviewable.set_priorities(medium: 3.0)
        SiteSetting.reviewable_default_visibility = 'medium'
        expect(execute.sent_reminder).to eq(false)
      end

      it "sends a message when `reviewable_default_visibility` is met" do
        Reviewable.set_priorities(medium: 2.0)
        SiteSetting.reviewable_default_visibility = 'medium'
        expect(execute.sent_reminder).to eq(true)
      end
    end
  end
end
