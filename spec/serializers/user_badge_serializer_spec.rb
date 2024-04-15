# frozen_string_literal: true

RSpec.describe UserBadgeSerializer do
  describe "#topic" do
    fab!(:user)
    fab!(:admin)
    fab!(:post)
    fab!(:badge) { Fabricate(:badge, show_posts: true) }
    fab!(:user_badge) { Fabricate(:user_badge, badge: badge, post_id: post.id) }
    let(:guardian) { Guardian.new(user_badge.user) }

    it "is not included in serialized object when badge has not been configured to show posts" do
      badge.update!(show_posts: false)

      guardian = Guardian.new

      serialized =
        described_class.new(
          user_badge,
          scope: guardian,
          allowed_user_badge_topic_ids: guardian.can_see_topic_ids(topic_ids: [post.topic_id]),
        ).as_json

      expect(serialized[:topics]).to eq(nil)
    end

    it "is not included in serialized object when user badge is not associated with a post" do
      user_badge.update!(post_id: nil)

      serialized =
        described_class.new(
          user_badge,
          scope: guardian,
          allowed_user_badge_topic_ids: guardian.can_see_topic_ids(topic_ids: [post.topic_id]),
        ).as_json

      expect(serialized[:topics]).to eq(nil)
    end

    it "is not included in serialized object when user badge is not associated with a topic" do
      post.topic.destroy!

      serialized =
        described_class.new(
          user_badge,
          scope: guardian,
          allowed_user_badge_topic_ids: guardian.can_see_topic_ids(topic_ids: [post.topic_id]),
        ).as_json

      expect(serialized[:topics]).to eq(nil)
    end

    it "is not included in serialized object when allowed_user_badge_topic_ids option is not provided" do
      serialized = described_class.new(user_badge, scope: guardian).as_json

      expect(serialized[:topics]).to eq(nil)
    end

    it "is not included in serialized object when topic id is not present in allowed_user_badge_topic_ids option" do
      serialized =
        described_class.new(
          user_badge,
          scope: guardian,
          allowed_user_badge_topic_ids: guardian.can_see_topic_ids(topic_ids: [post.topic_id + 1]),
        ).as_json

      expect(serialized[:topics]).to eq(nil)
    end

    it "is included in serialized object for admin scope even if allowed_user_badge_topic_ids option is not provided" do
      serialized = described_class.new(user_badge, scope: Guardian.new(admin)).as_json

      serialized_topic = serialized[:topics][0]

      expect(serialized_topic[:id]).to eq(post.topic_id)
      expect(serialized_topic[:title]).to eq(post.topic.title)
      expect(serialized_topic[:fancy_title]).to eq(post.topic.fancy_title)
      expect(serialized_topic[:slug]).to eq(post.topic.slug)
      expect(serialized_topic[:posts_count]).to eq(post.topic.reload.posts_count)
    end

    it "is included in serialized object when topic id is present in allowed_user_badge_topic_ids option" do
      serialized =
        described_class.new(
          user_badge,
          scope: guardian,
          allowed_user_badge_topic_ids: guardian.can_see_topic_ids(topic_ids: [post.topic_id]),
        ).as_json

      serialized_topic = serialized[:topics][0]

      expect(serialized_topic[:id]).to eq(post.topic_id)
      expect(serialized_topic[:title]).to eq(post.topic.title)
      expect(serialized_topic[:fancy_title]).to eq(post.topic.fancy_title)
      expect(serialized_topic[:slug]).to eq(post.topic.slug)
      expect(serialized_topic[:posts_count]).to eq(post.topic.reload.posts_count)
    end
  end
end
