# frozen_string_literal: true

RSpec.describe NestedReplies do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  before { SiteSetting.nested_replies_enabled = true }

  def build_chain(depth)
    posts = [op]
    depth.times do |i|
      reply_to = posts.last.post_number
      reply_to = nil if reply_to == 1
      posts << Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        reply_to_post_number: reply_to,
      )
    end
    posts
  end

  describe "basic walking" do
    it "returns ancestors from start_post_number to root" do
      chain = build_chain(4)
      results =
        NestedReplies.walk_ancestors(
          topic_id: topic.id,
          start_post_number: chain[4].reply_to_post_number,
        )
      expect(results).to be_an(Array)
      expect(results.length).to be >= 1
      expect(results.first.depth).to eq(1)
    end

    it "returns empty array when start post does not exist" do
      results = NestedReplies.walk_ancestors(topic_id: topic.id, start_post_number: 99_999)
      expect(results).to be_empty
    end

    it "respects the limit parameter" do
      chain = build_chain(5)
      results =
        NestedReplies.walk_ancestors(
          topic_id: topic.id,
          start_post_number: chain.last.reply_to_post_number,
          limit: 2,
        )
      expect(results.length).to be <= 2
    end
  end

  describe "exclude_deleted option" do
    it "skips deleted posts when exclude_deleted: true" do
      chain = build_chain(3)
      chain[2].update!(deleted_at: Time.current)

      results =
        NestedReplies.walk_ancestors(
          topic_id: topic.id,
          start_post_number: chain[3].reply_to_post_number,
          exclude_deleted: true,
        )
      post_numbers = results.map(&:post_number)
      expect(post_numbers).not_to include(chain[2].post_number)
    end

    it "includes deleted posts when exclude_deleted: false" do
      chain = build_chain(3)
      chain[2].update!(deleted_at: Time.current)

      results =
        NestedReplies.walk_ancestors(
          topic_id: topic.id,
          start_post_number: chain[3].reply_to_post_number,
          exclude_deleted: false,
        )
      post_numbers = results.map(&:post_number)
      expect(post_numbers).to include(chain[2].post_number)
    end
  end

  describe "stop_at_op option" do
    it "stops before OP when stop_at_op: true" do
      chain = build_chain(2)
      results =
        NestedReplies.walk_ancestors(
          topic_id: topic.id,
          start_post_number: chain[2].reply_to_post_number,
          stop_at_op: true,
        )
      post_numbers = results.map(&:post_number)
      expect(post_numbers).not_to include(1)
    end

    it "includes OP when stop_at_op: false" do
      reply_to_op = Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1)
      child =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: reply_to_op.post_number)

      results =
        NestedReplies.walk_ancestors(
          topic_id: topic.id,
          start_post_number: child.reply_to_post_number,
          stop_at_op: false,
        )
      post_numbers = results.map(&:post_number)
      expect(post_numbers).to include(1)
    end
  end

  describe "depth tracking" do
    it "assigns correct depth values" do
      chain = build_chain(3)
      results =
        NestedReplies.walk_ancestors(
          topic_id: topic.id,
          start_post_number: chain[3].reply_to_post_number,
        )
      expect(results.length).to eq(2)
      result_by_depth = results.index_by(&:depth)
      expect(result_by_depth[1].post_number).to eq(chain[2].post_number)
      expect(result_by_depth[2].post_number).to eq(chain[1].post_number)
    end
  end
end
