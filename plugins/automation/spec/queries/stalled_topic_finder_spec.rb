# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe StalledTopicFinder do
  before do
    SiteSetting.discourse_automation_enabled = true
    SiteSetting.tagging_enabled = true
    freeze_time
  end

  context 'default' do
    fab!(:topic_1) { create_topic }
    fab!(:topic_2) { create_topic }
    fab!(:topic_3) { create_topic }

    it 'returns only topics with no replies and at least one post' do
      create_post(topic: topic_1, user: topic_1.user)
      create_post(topic: topic_3, user: topic_3.user)
      create_post(topic: topic_3, user: topic_3.user)

      expect(described_class.call(2.hours.ago).map(&:id)).to contain_exactly(topic_1.id)
    end
  end

  context 'filter by tags' do
    fab!(:tag_1) { Fabricate(:tag) }
    fab!(:topic_1) { create_topic(tags: [tag_1.name]) }
    fab!(:topic_2) { create_topic }

    it 'returns only topics using the tag' do
      create_post(topic: topic_1, user: topic_1.user)
      create_post(topic: topic_2, user: topic_2.user)

      expect(described_class.call(2.hours.ago, tags: [tag_1.name]).map(&:id)).to contain_exactly(topic_1.id)
    end
  end

  context 'filter by categories' do
    fab!(:category_1) { Fabricate(:category) }
    fab!(:topic_1) { create_topic(category: category_1) }
    fab!(:topic_2) { create_topic }

    it 'returns only topics with the category' do
      create_post(topic: topic_1, user: topic_1.user)
      create_post(topic: topic_2, user: topic_1.user)

      expect(described_class.call(2.hours.ago, categories: [category_1.id]).map(&:id)).to contain_exactly(topic_1.id)
    end
  end

  context 'filter recent topic owner replies' do
    fab!(:topic_1) { create_topic }
    fab!(:topic_2) { create_topic }

    it 'returns only topics with old replies' do
      create_post(topic: topic_1, user: topic_1.user, created_at: 1.day.ago)
      create_post(topic: topic_1, user: topic_1.user, created_at: 1.day.ago)
      create_post(topic: topic_2, user: topic_2.user, created_at: 1.hour.ago)
      create_post(topic: topic_2, user: topic_2.user, created_at: 1.hour.ago)

      expect(described_class.call(5.hours.ago).map(&:id)).to contain_exactly(topic_1.id)
    end
  end
end
