# frozen_string_literal: true

describe DiscourseAutomation::StalledTopicFinder do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  before do
    SiteSetting.discourse_automation_enabled = true
    SiteSetting.tagging_enabled = true
    freeze_time
  end

  describe "default" do
    # topic with only stalled OP
    fab!(:topic_1) { create_topic(user: user) }
    # topic with recent replies
    fab!(:topic_2) { create_topic(user: user) }
    # topic with stalled replies
    fab!(:topic_3) { create_topic(user: user) }
    # topic with only recent OP
    fab!(:topic_4) { create_topic(user: user, created_at: 3.hours.from_now) }

    it "returns only stalled topics with replies" do
      create_post(topic: topic_1, user: user)
      create_post(topic: topic_2, user: user, created_at: 3.hours.from_now)
      create_post(topic: topic_2, user: user, created_at: 3.hours.from_now)
      create_post(topic: topic_3, user: user)
      create_post(topic: topic_3, user: user)

      expect(described_class.call(2.hours.from_now).map(&:id)).to contain_exactly(
        topic_1.id,
        topic_3.id,
      )
    end
  end

  describe "filter by tags" do
    fab!(:tag_1) { Fabricate(:tag) }
    # tagged topic with replies
    fab!(:topic_1) { create_topic(tags: [tag_1.name], user: user) }
    # untagged topic with replies
    fab!(:topic_2) { create_topic(user: user) }
    # tagged topic with no replies
    fab!(:topic_3) { create_topic(user: user, tags: [tag_1.name]) }
    # tagged topic with recent replies
    fab!(:topic_4) { create_topic(user: user, tags: [tag_1.name]) }

    it "returns only stalled topics with replies using the tag" do
      create_post(topic: topic_1, user: user)
      create_post(topic: topic_1, user: user)
      create_post(topic: topic_2, user: user)
      create_post(topic: topic_2, user: user)
      create_post(topic: topic_4, user: user, created_at: 3.hours.from_now)
      create_post(topic: topic_4, user: user, created_at: 3.hours.from_now)

      expect(
        described_class.call(2.hours.from_now, tags: [tag_1.name]).map(&:id),
      ).to contain_exactly(topic_1.id)
    end
  end

  describe "filter by categories" do
    fab!(:category_1) { Fabricate(:category) }

    # topic with stalled replies and category
    fab!(:topic_1) { create_topic(user: user, category: category_1) }
    # topic with stalled replies and no category
    fab!(:topic_2) { create_topic(user: user) }
    # topic with recent replies and category
    fab!(:topic_3) { create_topic(user: user, category: category_1) }

    it "returns only topics with the category" do
      create_post(topic: topic_1, user: user)
      create_post(topic: topic_1, user: user)
      create_post(topic: topic_2, user: user)
      create_post(topic: topic_2, user: user)
      create_post(topic: topic_3, user: user, created_at: 3.hours.from_now)
      create_post(topic: topic_3, user: user, created_at: 3.hours.from_now)

      expect(
        described_class.call(2.hours.from_now, categories: [category_1.id]).map(&:id),
      ).to contain_exactly(topic_1.id)
    end
  end

  describe "filter recent topic owner replies" do
    fab!(:another_user) { Fabricate(:user) }
    # replies from topic owner
    fab!(:topic_1) { create_topic(user: user) }
    # replies from not topic owner
    fab!(:topic_2) { create_topic(user: user) }

    it "doesn’t consider replies from other users" do
      create_post(topic: topic_1, user: user)
      create_post(topic: topic_1, user: user, created_at: 3.hours.from_now)
      create_post(topic: topic_2, user: user)
      create_post(topic: topic_2, user: another_user, created_at: 3.hours.from_now)

      expect(described_class.call(2.hours.from_now).map(&:id)).to contain_exactly(topic_2.id)
    end
  end
end
