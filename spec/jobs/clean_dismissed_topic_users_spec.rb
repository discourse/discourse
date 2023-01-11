# frozen_string_literal: true

RSpec.describe Jobs::CleanDismissedTopicUsers do
  fab!(:user) { Fabricate(:user, created_at: 1.days.ago, previous_visit_at: 1.days.ago) }
  fab!(:topic) { Fabricate(:topic, created_at: 5.hours.ago) }
  fab!(:dismissed_topic_user) { Fabricate(:dismissed_topic_user, user: user, topic: topic) }

  describe "#delete_overdue_dismissals!" do
    it "does not delete when new_topic_duration_minutes is set to always" do
      user.user_option.update(new_topic_duration_minutes: User::NewTopicDuration::ALWAYS)
      expect { described_class.new.execute({}) }.not_to change { DismissedTopicUser.count }
    end

    it "deletes when new_topic_duration_minutes is set to since last visit" do
      user.user_option.update(new_topic_duration_minutes: User::NewTopicDuration::LAST_VISIT)
      expect { described_class.new.execute({}) }.not_to change { DismissedTopicUser.count }

      user.update!(previous_visit_at: 1.hours.ago)
      expect { described_class.new.execute({}) }.to change { DismissedTopicUser.count }.by(-1)
    end

    it "deletes when new_topic_duration_minutes is set to created in the last day" do
      user.user_option.update(new_topic_duration_minutes: 1440)
      expect { described_class.new.execute({}) }.not_to change { DismissedTopicUser.count }

      topic.update!(created_at: 2.days.ago)
      expect { described_class.new.execute({}) }.to change { DismissedTopicUser.count }.by(-1)
    end
  end

  describe "#delete_over_the_limit_dismissals!" do
    fab!(:user2) { Fabricate(:user, created_at: 1.days.ago, previous_visit_at: 1.days.ago) }
    fab!(:topic2) { Fabricate(:topic, created_at: 6.hours.ago) }
    fab!(:topic3) { Fabricate(:topic, created_at: 2.hours.ago) }
    fab!(:dismissed_topic_user2) { Fabricate(:dismissed_topic_user, user: user, topic: topic2) }
    fab!(:dismissed_topic_user3) { Fabricate(:dismissed_topic_user, user: user, topic: topic3) }
    fab!(:dismissed_topic_user4) { Fabricate(:dismissed_topic_user, user: user2, topic: topic) }

    before do
      user.user_option.update(new_topic_duration_minutes: User::NewTopicDuration::ALWAYS)
      user2.user_option.update(new_topic_duration_minutes: User::NewTopicDuration::ALWAYS)
    end

    it "deletes over the limit dismissals" do
      described_class.new.execute({})
      expect(dismissed_topic_user.reload).to be_present
      expect(dismissed_topic_user2.reload).to be_present
      expect(dismissed_topic_user3.reload).to be_present
      expect(dismissed_topic_user4.reload).to be_present

      SiteSetting.max_new_topics = 2
      described_class.new.execute({})
      expect(dismissed_topic_user.reload).to be_present
      expect { dismissed_topic_user2.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(dismissed_topic_user3.reload).to be_present
      expect(dismissed_topic_user4.reload).to be_present
    end
  end
end
