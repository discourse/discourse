# frozen_string_literal: true

RSpec.describe "Nested replies N+1 elimination", type: :request do
  include NestedRepliesHelpers

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  before { SiteSetting.nested_replies_enabled = true }

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
    it "maintains stats during preparation while nested replies are disabled" do
      SiteSetting.nested_replies_enabled = false
      SiteSetting.nested_replies_stats_maintenance_enabled = true

      parent = Fabricate(:post, topic: topic, user: user, reply_to_post_number: op.post_number)
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: parent.post_number)

      expect(NestedViewPostStat.find_by(post_id: op.id)).to have_attributes(
        direct_reply_count: 1,
        total_descendant_count: 2,
      )
      expect(NestedViewPostStat.find_by(post_id: parent.id)).to have_attributes(
        direct_reply_count: 1,
        total_descendant_count: 1,
      )
    end

    it "uses constant queries regardless of chain depth" do
      chain_3 = create_reply_chain(depth: 3)
      queries_3 =
        track_sql_queries do
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain_3.last.post_number)
        end

      topic2 = Fabricate(:topic, user: user)
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

      stats_queries_3 = queries_3.count { |q| q.include?("nested_view_post_stats") }
      stats_queries_10 = queries_10.count { |q| q.include?("nested_view_post_stats") }
      expect(stats_queries_3).to eq(stats_queries_10)
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
  end

  describe "after_destroy stats decrement" do
    it "uses constant queries regardless of chain depth" do
      chain_3 = create_reply_chain(depth: 3)
      leaf_3 =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: chain_3.last.post_number)
      queries_3 = track_sql_queries { leaf_3.destroy! }

      topic2 = Fabricate(:topic, user: user)
      Fabricate(:post, topic: topic2, user: user, post_number: 1)
      chain_10 = create_reply_chain(depth: 10, in_topic: topic2)
      leaf_10 =
        Fabricate(:post, topic: topic2, user: user, reply_to_post_number: chain_10.last.post_number)
      queries_10 = track_sql_queries { leaf_10.destroy! }

      stats_queries_3 = queries_3.count { |q| q.include?("nested_view_post_stats") }
      stats_queries_10 = queries_10.count { |q| q.include?("nested_view_post_stats") }
      expect(stats_queries_3).to eq(stats_queries_10)
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

  describe "hot sorting" do
    def build_hot_topic(root_count)
      hot_topic = Fabricate(:topic, user: user)
      Fabricate(:post, topic: hot_topic, user: user, post_number: 1)
      Fabricate(:nested_topic, topic: hot_topic)
      root_count.times { Fabricate(:post, topic: hot_topic, user: user) }
      hot_topic.update_columns(posts_count: root_count + 1, last_posted_at: Time.current)
      NestedReplies::HotScoreCalculator.recalculate_topic(hot_topic.id)
      hot_topic
    end

    it "uses a constant number of cache queries as the root count grows" do
      SiteSetting.nested_replies_hot_sort_enabled = true
      small_topic = build_hot_topic(5)
      large_topic = build_hot_topic(50)
      sign_in(user)

      small_queries =
        track_sql_queries { get "/n/#{small_topic.slug}/#{small_topic.id}.json?sort=hot" }
      large_queries =
        track_sql_queries { get "/n/#{large_topic.slug}/#{large_topic.id}.json?sort=hot" }
      cache_query = /nested_hot_(post_scores|score_snapshots)/
      small_cache_query_count = small_queries.grep(cache_query).size

      expect(small_cache_query_count).to be_positive
      expect(large_queries.grep(cache_query).size).to eq(small_cache_query_count)
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
