# frozen_string_literal: true

RSpec.describe NestedReplies::TreeLoader do
  fab!(:user)
  fab!(:admin)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

  fab!(:root) { Fabricate(:post, topic: topic, reply_to_post_number: op.post_number) }

  fab!(:child) { Fabricate(:post, topic: topic, reply_to_post_number: root.post_number) }

  before do
    SiteSetting.nested_replies_enabled = true
    NestedReplies::RecalculationQueue.clear
  end

  after { NestedReplies::RecalculationQueue.clear }

  describe "#total_descendant_counts" do
    it "stops live counts at malformed cycles" do
      root.update_columns(reply_to_post_number: child.post_number)
      NestedViewPostStat.where(post_id: [root.id, child.id]).delete_all

      regular_counts =
        described_class.new(topic: topic, guardian: user.guardian).total_descendant_counts([root])
      staff_counts =
        described_class.new(topic: topic, guardian: admin.guardian).total_descendant_counts([root])

      expect([regular_counts[root.id], staff_counts[root.id]]).to eq([1, 1])
    end

    it "uses live counts until structural backfill completes" do
      root_stat = NestedViewPostStat.find_or_create_by!(post: root)
      root_stat.update_columns(total_descendant_count: 99)
      NestedViewPostStat.where(post: op).update_all(structural_backfilled_at: nil)

      counts =
        described_class.new(topic: topic, guardian: user.guardian).total_descendant_counts([root])

      expect(counts[root.id]).to eq(1)
    end

    it "uses live counts when the completion marker predates the cutoff" do
      root_stat = NestedViewPostStat.find_or_create_by!(post: root)
      root_stat.update_columns(total_descendant_count: 99)
      marker = NestedViewPostStat.find_or_create_by!(post: op)
      marker.update_columns(structural_backfilled_at: 1.hour.ago)
      SiteSetting.nested_replies_stats_valid_after = 1.minute.ago.to_f

      counts =
        described_class.new(topic: topic, guardian: user.guardian).total_descendant_counts([root])

      expect(counts[root.id]).to eq(1)
    end

    it "serves staff and regular cached counts without recursion", :aggregate_failures do
      SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
      Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
      Fabricate(
        :post,
        topic: topic,
        reply_to_post_number: root.post_number,
        post_type: Post.types[:whisper],
      )
      action_whisper =
        Fabricate(
          :post,
          topic: topic,
          reply_to_post_number: root.post_number,
          post_type: Post.types[:whisper],
          action_code: "assigned",
        )
      action_child = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
      action_child.update_columns(reply_to_post_number: action_whisper.post_number)
      NestedReplies::StructuralStats.recalculate_topic(topic.id)

      queries =
        track_sql_queries do
          regular_counts =
            described_class.new(topic: topic, guardian: user.guardian).total_descendant_counts(
              [root],
            )
          staff_counts =
            described_class.new(topic: topic, guardian: admin.guardian).total_descendant_counts(
              [root],
            )

          expect(regular_counts[root.id]).to eq(3)
          expect(staff_counts[root.id]).to eq(4)
        end

      expect(queries.grep(/WITH RECURSIVE descendants/)).to be_empty
      root_stat = NestedViewPostStat.find_by!(post: root)
      expect(root_stat.total_descendant_count).to eq(4)
      expect(root_stat.whisper_total_descendant_count).to eq(1)
    end
  end

  describe "#root_posts_scope" do
    it "uses reply engagement when hot scores are missing" do
      engaged_root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      3.times { Fabricate(:post, topic: topic, reply_to_post_number: engaged_root.post_number) }
      root.update_columns(created_at: 1.day.ago, reply_count: 100)
      engaged_root.update_columns(created_at: root.created_at, reply_count: 0)
      NestedViewPostStat.where(post_id: [root.id, engaged_root.id]).delete_all
      loader = described_class.new(topic: topic, guardian: user.guardian)

      root_ids = loader.root_posts_scope("hot").limit(2).pluck(:id)

      expect(root_ids).to eq([engaged_root.id, root.id])
    end

    it "falls back when a candidate score predates the cutoff" do
      engaged_root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      2.times { Fabricate(:post, topic: topic, reply_to_post_number: engaged_root.post_number) }
      created_at = 1.day.ago
      root.update_columns(created_at: created_at, reply_count: 100)
      engaged_root.update_columns(created_at: created_at, reply_count: 0)
      cutoff = 1.minute.ago
      SiteSetting.nested_replies_stats_valid_after = cutoff.to_f
      NestedViewPostStat.find_or_initialize_by(post: op).update!(hot_score_updated_at: Time.current)
      NestedViewPostStat.find_or_initialize_by(post: root).update!(
        hot_score: 100,
        thread_hot_score: 100,
        hot_score_updated_at: 1.hour.ago,
      )
      NestedViewPostStat.find_or_initialize_by(post: engaged_root).update!(
        hot_score: 0,
        thread_hot_score: 0,
        hot_score_updated_at: 1.hour.ago,
      )

      root_ids =
        described_class
          .new(topic: topic, guardian: user.guardian)
          .root_posts_scope("hot")
          .limit(2)
          .pluck(:id)

      expect(root_ids).to eq([engaged_root.id, root.id])
    end
  end
end
