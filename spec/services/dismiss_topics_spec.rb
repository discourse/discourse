# frozen_string_literal: true

require 'rails_helper'

describe DismissTopics do
  fab!(:user) { Fabricate(:user, created_at: 1.days.ago) }
  fab!(:category) { Fabricate(:category) }
  fab!(:topic1) { Fabricate(:topic, category: category, created_at: 60.minutes.ago) }
  fab!(:topic2) { Fabricate(:topic, category: category, created_at: 120.minutes.ago) }

  describe '#perform!' do
    it 'dismisses two topics' do
      expect { described_class.new(user, Topic.all).perform! }.to change { DismissedTopicUser.count }.by(2)
    end

    it 'returns dismissed topic ids' do
      expect(described_class.new(user, Topic.all).perform!.sort).to eq([topic1.id, topic2.id])
    end

    it 'respects max_new_topics limit' do
      SiteSetting.max_new_topics = 1
      expect { described_class.new(user, Topic.all).perform! }.to change { DismissedTopicUser.count }.by(1)

      dismissed_topic_user = DismissedTopicUser.last

      expect(dismissed_topic_user.user_id).to eq(user.id)
      expect(dismissed_topic_user.topic_id).to eq(topic1.id)
      expect(dismissed_topic_user.created_at).not_to be_nil
    end

    it 'respects seen topics' do
      Fabricate(:topic_user, user: user, topic: topic1, last_read_post_number: 1)
      Fabricate(:topic_user, user: user, topic: topic2, last_read_post_number: 1)
      expect { described_class.new(user, Topic.all).perform! }.to change { DismissedTopicUser.count }.by(0)
    end

    it 'dismisses when topic user without last_read_post_number' do
      Fabricate(:topic_user, user: user, topic: topic1, last_read_post_number: nil)
      Fabricate(:topic_user, user: user, topic: topic2, last_read_post_number: nil)
      expect { described_class.new(user, Topic.all).perform! }.to change { DismissedTopicUser.count }.by(2)
    end

    it 'respects new_topic_duration_minutes' do
      user.user_option.update!(new_topic_duration_minutes: 70)

      expect { described_class.new(user, Topic.all).perform! }.to change { DismissedTopicUser.count }.by(1)

      dismissed_topic_user = DismissedTopicUser.last

      expect(dismissed_topic_user.user_id).to eq(user.id)
      expect(dismissed_topic_user.topic_id).to eq(topic1.id)
      expect(dismissed_topic_user.created_at).not_to be_nil
    end
  end
end
