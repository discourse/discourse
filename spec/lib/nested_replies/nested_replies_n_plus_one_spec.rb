# frozen_string_literal: true

RSpec.describe "Nested replies N+1 elimination", type: :request do
  include NestedRepliesHelpers

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }
  fab!(:op) { Fabricate(:post, topic: topic.reload, user: user, post_number: 1) }

  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_stats_valid_after = 0
    NestedReplies::RecalculationQueue.clear
  end

  after { NestedReplies::RecalculationQueue.clear }

  def nested_reply_counter_stat_queries(queries)
    queries.count do |query|
      query.include?("nested_view_post_stats") &&
        (query.include?("direct_reply_count") || query.include?("total_descendant_count"))
    end
  end

  def nested_hot_score_queries(queries)
    queries.count do |query|
      query.include?("nested_view_post_stats") &&
        (query.include?("hot_score") || query.include?("thread_hot_score"))
    end
  end

  describe "no re-parenting on create" do
    before do
      SiteSetting.nested_replies_cap_nesting_depth = true
      SiteSetting.nested_replies_max_depth = 3
    end

    it "preserves reply_to_post_number even at max depth" do
      chain = create_reply_chain(depth: 4)
      deep_reply =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain.last.post_number)
      expect(deep_reply.reply_to_post_number).to eq(chain.last.post_number)
    end

    it "preserves reply_to_post_number under max depth" do
      SiteSetting.nested_replies_max_depth = 10
      chain = create_reply_chain(depth: 3)
      reply =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain.last.post_number)
      expect(reply.reply_to_post_number).to eq(chain.last.post_number)
    end
  end

  describe "after_create stats increment" do
    it "does not track structural stats for a flat topic" do
      flat_topic = Fabricate(:topic, user: user)
      flat_op = Fabricate(:post, topic: flat_topic, user: user, post_number: 1)

      Fabricate(:post, topic: flat_topic, user: user, reply_to_post_number: flat_op.post_number)

      expect(NestedViewPostStat.find_by(post: flat_op)).to be_nil
    end

    it "uses constant queries regardless of chain depth" do
      chain_3 = create_reply_chain(depth: 3)
      queries_3 =
        track_sql_queries do
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain_3.last.post_number)
        end

      topic2 = Fabricate(:topic, user: user)
      Fabricate(:nested_topic, topic: topic2)
      Fabricate(:post, topic: topic2, user: user, post_number: 1)
      chain_10 = create_reply_chain(depth: 10, in_topic: topic2)
      queries_10 =
        track_sql_queries do
          Fabricate(
            :post,
            topic: topic2,
            user: user,
            reply_to_post_number: chain_10.last.post_number,
          )
        end

      counter_stat_queries_3 = nested_reply_counter_stat_queries(queries_3)
      counter_stat_queries_10 = nested_reply_counter_stat_queries(queries_10)
      expect(counter_stat_queries_3).to be_positive
      expect(counter_stat_queries_3).to eq(counter_stat_queries_10)
    end

    it "increments direct_reply_count on parent only and total_descendant_count on all ancestors" do
      chain = create_reply_chain(depth: 3)
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain.last.post_number)

      chain.each(&:reload)

      parent_stat = NestedViewPostStat.find_by(post_id: chain.last.id)
      expect(parent_stat.direct_reply_count).to eq(1)
      expect(parent_stat.total_descendant_count).to eq(1)

      chain[0..-2].each do |ancestor|
        stat = NestedViewPostStat.find_by(post_id: ancestor.id)
        expect(stat).to be_present
        expect(stat.direct_reply_count).to eq(0).or eq(1)
        expect(stat.total_descendant_count).to be >= 1
      end
    end

    it "tracks whisper counts separately from regular counts" do
      chain = create_reply_chain(depth: 2)
      Fabricate(
        :post,
        topic: topic,
        user: user,
        reply_to_post_number: chain.last.post_number,
        post_type: Post.types[:whisper],
      )

      parent_stat = NestedViewPostStat.find_by(post_id: chain.last.id)
      expect(parent_stat.direct_reply_count).to eq(1)
      expect(parent_stat.whisper_direct_reply_count).to eq(1)
      expect(parent_stat.total_descendant_count).to eq(1)
      expect(parent_stat.whisper_total_descendant_count).to eq(1)
    end

    it "does not increment whisper counts for regular posts" do
      chain = create_reply_chain(depth: 2)
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain.last.post_number)

      parent_stat = NestedViewPostStat.find_by(post_id: chain.last.id)
      expect(parent_stat.direct_reply_count).to eq(1)
      expect(parent_stat.whisper_direct_reply_count).to eq(0)
      expect(parent_stat.total_descendant_count).to eq(1)
      expect(parent_stat.whisper_total_descendant_count).to eq(0)
    end

    it "increments whisper counts on all ancestors" do
      chain = create_reply_chain(depth: 3)
      Fabricate(
        :post,
        topic: topic,
        user: user,
        reply_to_post_number: chain.last.post_number,
        post_type: Post.types[:whisper],
      )

      chain.each do |ancestor|
        stat = NestedViewPostStat.find_by(post_id: ancestor.id)
        next unless stat
        expect(stat.whisper_total_descendant_count).to be >= 1
      end
    end

    it "ignores small actions while counting descendants below them" do
      parent = Fabricate(:post, topic: topic, user: user, reply_to_post_number: op.post_number)
      small_action =
        Fabricate(:small_action, topic: topic, user: user, reply_to_post_number: parent.post_number)

      Fabricate(:post, topic: topic, user: user, reply_to_post_number: small_action.post_number)

      parent_stat = NestedViewPostStat.find_by!(post: parent)
      expect([parent_stat.direct_reply_count, parent_stat.total_descendant_count]).to eq([0, 1])
    end
  end

  describe "after_update stats adjustment" do
    it "tracks regular, whisper, and small-action transitions" do
      parent = Fabricate(:post, topic: topic, user: user, reply_to_post_number: op.post_number)
      child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: parent.post_number)
      parent_stat = NestedViewPostStat.find_by!(post: parent)

      child.update!(post_type: Post.types[:whisper])
      whisper_counts =
        parent_stat.reload.attributes.values_at(
          "direct_reply_count",
          "total_descendant_count",
          "whisper_direct_reply_count",
          "whisper_total_descendant_count",
        )

      child.update!(post_type: Post.types[:small_action])
      small_action_counts =
        parent_stat.reload.attributes.values_at(
          "direct_reply_count",
          "total_descendant_count",
          "whisper_direct_reply_count",
          "whisper_total_descendant_count",
        )

      child.update!(post_type: Post.types[:regular])
      regular_counts =
        parent_stat.reload.attributes.values_at(
          "direct_reply_count",
          "total_descendant_count",
          "whisper_direct_reply_count",
          "whisper_total_descendant_count",
        )

      expect(whisper_counts).to eq([1, 1, 1, 1])
      expect(small_action_counts).to eq([0, 0, 0, 0])
      expect(regular_counts).to eq([1, 1, 0, 0])
    end

    it "moves a subtree while changing its post type" do
      old_parent = Fabricate(:post, topic: topic, user: user, reply_to_post_number: op.post_number)
      new_parent = Fabricate(:post, topic: topic, user: user, reply_to_post_number: op.post_number)
      child =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: old_parent.post_number)
      Fabricate(
        :post,
        topic: topic,
        user: user,
        reply_to_post_number: child.post_number,
        post_type: Post.types[:whisper],
      )

      child.update!(reply_to_post_number: new_parent.post_number, post_type: Post.types[:whisper])

      old_stat = NestedViewPostStat.find_by!(post: old_parent)
      new_stat = NestedViewPostStat.find_by!(post: new_parent)
      expect(
        old_stat.attributes.values_at(
          "direct_reply_count",
          "total_descendant_count",
          "whisper_direct_reply_count",
          "whisper_total_descendant_count",
        ),
      ).to eq([0, 0, 0, 0])
      expect(
        new_stat.attributes.values_at(
          "direct_reply_count",
          "total_descendant_count",
          "whisper_direct_reply_count",
          "whisper_total_descendant_count",
        ),
      ).to eq([1, 2, 1, 2])
    end

    it "removes and restores an action-code whisper" do
      parent = Fabricate(:post, topic: topic, user: user, reply_to_post_number: op.post_number)
      whisper =
        Fabricate(
          :post,
          topic: topic,
          user: user,
          reply_to_post_number: parent.post_number,
          post_type: Post.types[:whisper],
        )
      parent_stat = NestedViewPostStat.find_by!(post: parent)

      whisper.update!(action_code: "assigned")
      action_counts =
        parent_stat.reload.attributes.values_at(
          "direct_reply_count",
          "total_descendant_count",
          "whisper_direct_reply_count",
          "whisper_total_descendant_count",
        )
      whisper.update!(action_code: nil)
      visible_counts =
        parent_stat.reload.attributes.values_at(
          "direct_reply_count",
          "total_descendant_count",
          "whisper_direct_reply_count",
          "whisper_total_descendant_count",
        )

      expect(action_counts).to eq([0, 0, 0, 0])
      expect(visible_counts).to eq([1, 1, 1, 1])
    end

    it "queues and runs an exact rebuild after reparenting", :aggregate_failures do
      old_parent = Fabricate(:post, topic: topic, user: user, reply_to_post_number: op.post_number)
      new_parent = Fabricate(:post, topic: topic, user: user, reply_to_post_number: op.post_number)
      child =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: old_parent.post_number)
      NestedReplies::StructuralStats.recalculate_topic(topic.id)
      NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
      NestedReplies::RecalculationQueue.clear

      expect_enqueued_with(job: :process_nested_reply_updates) do
        PostRevisor.new(child).revise!(user, reply_to_post_number: new_parent.post_number)
      end

      marker = NestedViewPostStat.find_by!(post: op)
      expect(marker.structural_backfilled_at).to be_nil
      expect(marker.hot_score_updated_at).to be_nil

      Jobs::ProcessNestedReplyUpdates.new.execute

      expect(child.reload.reply_to_post_number).to eq(new_parent.post_number)
      expect(NestedViewPostStat.find_by!(post: old_parent).direct_reply_count).to eq(0)
      expect(NestedViewPostStat.find_by!(post: new_parent).direct_reply_count).to eq(1)
      expect(marker.reload.structural_backfilled_at).to be_present
      expect(marker.hot_score_updated_at).to be_present
    end
  end

  describe "after_destroy stats decrement" do
    it "uses constant queries regardless of chain depth" do
      chain_3 = create_reply_chain(depth: 3)
      leaf_3 =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain_3.last.post_number)
      queries_3 = track_sql_queries { leaf_3.destroy! }

      topic2 = Fabricate(:topic, user: user)
      Fabricate(:nested_topic, topic: topic2)
      Fabricate(:post, topic: topic2, user: user, post_number: 1)
      chain_10 = create_reply_chain(depth: 10, in_topic: topic2)
      leaf_10 =
        Fabricate(:post, topic: topic2, user: user, reply_to_post_number: chain_10.last.post_number)
      queries_10 = track_sql_queries { leaf_10.destroy! }

      counter_stat_queries_3 = nested_reply_counter_stat_queries(queries_3)
      counter_stat_queries_10 = nested_reply_counter_stat_queries(queries_10)
      expect(counter_stat_queries_3).to be_positive
      expect(counter_stat_queries_3).to eq(counter_stat_queries_10)
    end

    it "clamps stats at zero" do
      chain = create_reply_chain(depth: 2)
      leaf =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain.last.post_number)
      leaf.destroy!

      chain.each do |post|
        stat = NestedViewPostStat.find_by(post_id: post.id)
        next unless stat
        expect(stat.total_descendant_count).to be >= 0
        expect(stat.direct_reply_count).to be >= 0
      end
    end

    it "cleans up the destroyed post's own stat row" do
      chain = create_reply_chain(depth: 2)
      leaf =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain.last.post_number)
      leaf_id = leaf.id
      leaf.destroy!
      expect(NestedViewPostStat.find_by(post_id: leaf_id)).to be_nil
    end

    it "decrements whisper counts when a whisper is destroyed" do
      chain = create_reply_chain(depth: 2)
      whisper =
        Fabricate(
          :post,
          topic: topic,
          user: user,
          reply_to_post_number: chain.last.post_number,
          post_type: Post.types[:whisper],
        )

      parent_stat = NestedViewPostStat.find_by(post_id: chain.last.id)
      expect(parent_stat.whisper_direct_reply_count).to eq(1)
      expect(parent_stat.whisper_total_descendant_count).to eq(1)

      whisper.destroy!

      parent_stat.reload
      expect(parent_stat.direct_reply_count).to eq(0)
      expect(parent_stat.whisper_direct_reply_count).to eq(0)
      expect(parent_stat.total_descendant_count).to eq(0)
      expect(parent_stat.whisper_total_descendant_count).to eq(0)
    end

    it "does not decrement whisper counts when a regular post is destroyed" do
      chain = create_reply_chain(depth: 2)
      Fabricate(
        :post,
        topic: topic,
        user: user,
        reply_to_post_number: chain.last.post_number,
        post_type: Post.types[:whisper],
      )
      regular =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain.last.post_number)

      regular.destroy!

      parent_stat = NestedViewPostStat.find_by(post_id: chain.last.id)
      expect(parent_stat.direct_reply_count).to eq(1)
      expect(parent_stat.whisper_direct_reply_count).to eq(1)
    end

    it "queues and runs an exact rebuild after a hard delete", :aggregate_failures do
      parent = Fabricate(:post, topic: topic, user: user, reply_to_post_number: op.post_number)
      child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: parent.post_number)
      NestedReplies::StructuralStats.recalculate_topic(topic.id)
      NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
      original_hot_marker = NestedViewPostStat.find_by!(post: op).hot_score_updated_at
      NestedReplies::RecalculationQueue.clear

      expect_enqueued_with(job: :process_nested_reply_updates) { child.destroy! }

      marker = NestedViewPostStat.find_by!(post: op)
      expect(marker.structural_backfilled_at).to be_nil
      expect(marker.hot_score_updated_at).to eq_time(original_hot_marker)

      Jobs::ProcessNestedReplyUpdates.new.execute

      expect(NestedViewPostStat.find_by!(post: parent).direct_reply_count).to eq(0)
      expect(marker.reload.structural_backfilled_at).to be_present
      expect(marker.hot_score_updated_at).to eq_time(original_hot_marker)
    end
  end

  describe "hot score calculation" do
    it "uses constant queries regardless of chain depth" do
      chain_3 = create_reply_chain(depth: 3)
      queries_3 =
        track_sql_queries do
          NestedReplies::HotScoreCalculator.recalculate_for_post(chain_3.last.id)
        end

      topic2 = Fabricate(:topic, user: user)
      Fabricate(:nested_topic, topic: topic2)
      Fabricate(:post, topic: topic2, user: user, post_number: 1)
      chain_10 = create_reply_chain(depth: 10, in_topic: topic2)
      queries_10 =
        track_sql_queries do
          NestedReplies::HotScoreCalculator.recalculate_for_post(chain_10.last.id)
        end

      hot_queries_3 = nested_hot_score_queries(queries_3)
      hot_queries_10 = nested_hot_score_queries(queries_10)
      expect(hot_queries_3).to be_positive
      expect(hot_queries_3).to eq(hot_queries_10)
    end
  end

  describe "context endpoint" do
    fab!(:admin)

    def context_url(topic, post_number, context_depth: nil)
      url = "/n/#{topic.slug}/#{topic.id}/context/#{post_number}.json"
      url += "?context=#{context_depth}" if context_depth
      url
    end

    it "uses constant queries regardless of ancestor depth" do
      chain_3 = create_reply_chain(depth: 3)

      sign_in(admin)

      # Warm up
      get context_url(topic, chain_3.last.post_number)
      expect(response.status).to eq(200)

      queries_3 = track_sql_queries { get context_url(topic, chain_3.last.post_number) }

      topic2 = Fabricate(:topic, user: user)
      Fabricate(:nested_topic, topic: topic2)
      Fabricate(:post, topic: topic2, user: user, post_number: 1)
      chain_10 = create_reply_chain(depth: 10, in_topic: topic2)

      # Warm up
      get context_url(topic2, chain_10.last.post_number)

      queries_10 = track_sql_queries { get context_url(topic2, chain_10.last.post_number) }

      ancestor_queries_3 = queries_3.count { |q| q.include?("WITH RECURSIVE ancestors") }
      ancestor_queries_10 = queries_10.count { |q| q.include?("WITH RECURSIVE ancestors") }
      expect(ancestor_queries_3).to eq(ancestor_queries_10)
      expect(ancestor_queries_3).to eq(1)
    end

    it "returns the correct ancestor chain" do
      SiteSetting.nested_replies_max_depth = 5
      chain = create_reply_chain(depth: 5)
      sign_in(admin)

      get context_url(topic, chain.last.post_number)
      expect(response.status).to eq(200)

      json = response.parsed_body
      ancestor_numbers = json["ancestor_chain"].map { |a| a["post_number"] }
      expected = chain[0..-2].map(&:post_number)
      expect(ancestor_numbers).to eq(expected)
    end

    it "respects context_depth parameter" do
      chain = create_reply_chain(depth: 5)
      sign_in(admin)

      get context_url(topic, chain.last.post_number, context_depth: 2)
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["ancestor_chain"].length).to eq(2)
    end

    it "preserves deleted ancestors as placeholders to keep chains intact" do
      chain = create_reply_chain(depth: 4)
      chain[1].update!(deleted_at: Time.current)

      regular_user = Fabricate(:user)
      sign_in(regular_user)
      get context_url(topic, chain.last.post_number)
      expect(response.status).to eq(200)

      json = response.parsed_body
      ancestor_numbers = json["ancestor_chain"].map { |a| a["post_number"] }
      expect(ancestor_numbers).to include(chain[1].post_number)

      deleted_ancestor =
        json["ancestor_chain"].find { |a| a["post_number"] == chain[1].post_number }
      expect(deleted_ancestor["deleted_post_placeholder"]).to eq(true)
    end
  end

  describe "edge cases" do
    it "handles reply to OP (no ancestors)" do
      reply = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      expect(NestedViewPostStat.find_by(post_id: op.id)).to be_nil
    end

    it "handles reply to deleted parent gracefully" do
      chain = create_reply_chain(depth: 2)
      chain.last.update!(deleted_at: Time.current)

      expect {
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain.last.post_number)
      }.not_to raise_error
    end

    it "increments all ancestors including deleted intermediaries" do
      chain = create_reply_chain(depth: 3)
      grandparent = chain[0]
      parent = chain[1]
      child = chain[2]

      grandparent_before =
        NestedViewPostStat.find_by(post_id: grandparent.id).total_descendant_count
      parent_before = NestedViewPostStat.find_by(post_id: parent.id).total_descendant_count

      parent.update!(deleted_at: Time.current)

      Fabricate(:post, topic: topic, user: user, reply_to_post_number: child.post_number)

      expect(NestedViewPostStat.find_by(post_id: child.id).total_descendant_count).to eq(1)
      expect(NestedViewPostStat.find_by(post_id: parent.id).total_descendant_count).to eq(
        parent_before + 1,
      )
      expect(NestedViewPostStat.find_by(post_id: grandparent.id).total_descendant_count).to eq(
        grandparent_before + 1,
      )
    end
  end
end
