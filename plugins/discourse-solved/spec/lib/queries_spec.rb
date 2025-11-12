# frozen_string_literal: true

describe DiscourseSolved::Queries do
  fab!(:user)
  fab!(:admin)

  describe ".solved_count" do
    it "returns the correct count of solved topics for a user" do
      expect(described_class.solved_count(user.id)).to eq(0)

      topic1 = Fabricate(:topic)
      Fabricate(:post, topic: topic1)
      post1 = Fabricate(:post, topic: topic1, user: user)
      DiscourseSolved.accept_answer!(post1, admin)

      expect(described_class.solved_count(user.id)).to eq(1)

      topic2 = Fabricate(:topic)
      Fabricate(:post, topic: topic2)
      post2 = Fabricate(:post, topic: topic2, user: user)
      DiscourseSolved.accept_answer!(post2, admin)

      expect(described_class.solved_count(user.id)).to eq(2)
    end

    it "excludes deleted posts from the count" do
      topic = Fabricate(:topic)
      Fabricate(:post, topic: topic)
      post = Fabricate(:post, topic: topic, user: user)

      DiscourseSolved.accept_answer!(post, admin)
      expect(described_class.solved_count(user.id)).to eq(1)

      post.update!(deleted_at: Time.zone.now)
      expect(described_class.solved_count(user.id)).to eq(0)
    end

    it "excludes deleted topics from the count" do
      topic = Fabricate(:topic)
      Fabricate(:post, topic: topic)
      post = Fabricate(:post, topic: topic, user: user)

      DiscourseSolved.accept_answer!(post, admin)
      expect(described_class.solved_count(user.id)).to eq(1)

      topic.update!(deleted_at: Time.zone.now)
      expect(described_class.solved_count(user.id)).to eq(0)
    end

    it "excludes private messages from the count" do
      topic = Fabricate(:topic)
      Fabricate(:post, topic: topic)
      post = Fabricate(:post, topic: topic, user: user)
      DiscourseSolved.accept_answer!(post, admin)

      pm = Fabricate(:topic, archetype: Archetype.private_message, category_id: nil)
      Fabricate(:post, topic: pm)
      pm_post = Fabricate(:post, topic: pm, user: user)
      DiscourseSolved.accept_answer!(pm_post, admin)

      expect(described_class.solved_count(user.id)).to eq(1)
    end

    it "returns 0 for users with no solutions" do
      expect(described_class.solved_count(user.id)).to eq(0)
      expect(described_class.solved_count(admin.id)).to eq(0)
    end
  end
end
