# frozen_string_literal: true

describe DiscourseSolved::Queries do
  fab!(:user)

  describe ".solved_count" do
    it "returns the correct count of solved topics for a user" do
      expect(described_class.solved_count(user.id)).to eq(0)

      topic1 = Fabricate(:topic)
      post1 = Fabricate(:post, topic: topic1, user: user)
      Fabricate(:solved_topic, topic: topic1, answer_post: post1)

      expect(described_class.solved_count(user.id)).to eq(1)

      topic2 = Fabricate(:topic)
      post2 = Fabricate(:post, topic: topic2, user: user)
      Fabricate(:solved_topic, topic: topic2, answer_post: post2)

      expect(described_class.solved_count(user.id)).to eq(2)
    end

    it "excludes deleted posts from the count" do
      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic, user: user)

      Fabricate(:solved_topic, topic: topic, answer_post: post)
      expect(described_class.solved_count(user.id)).to eq(1)

      post.update!(deleted_at: Time.zone.now)
      expect(described_class.solved_count(user.id)).to eq(0)
    end

    it "excludes deleted topics from the count" do
      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic, user: user)

      Fabricate(:solved_topic, topic: topic, answer_post: post)
      expect(described_class.solved_count(user.id)).to eq(1)

      topic.update!(deleted_at: Time.zone.now)
      expect(described_class.solved_count(user.id)).to eq(0)
    end

    it "excludes private messages from the count" do
      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic, user: user)
      Fabricate(:solved_topic, topic: topic, answer_post: post)

      pm = Fabricate(:topic, archetype: Archetype.private_message, category_id: nil)
      pm_post = Fabricate(:post, topic: pm, user: user)
      Fabricate(:solved_topic, topic: pm, answer_post: pm_post)

      expect(described_class.solved_count(user.id)).to eq(1)
    end

    it "returns 0 for users with no solutions" do
      expect(described_class.solved_count(user.id)).to eq(0)
    end
  end
end
