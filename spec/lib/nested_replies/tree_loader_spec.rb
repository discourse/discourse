# frozen_string_literal: true

RSpec.describe NestedReplies::TreeLoader do
  fab!(:user)
  fab!(:admin)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

  fab!(:root) { Fabricate(:post, topic: topic, reply_to_post_number: op.post_number) }

  fab!(:child) { Fabricate(:post, topic: topic, reply_to_post_number: root.post_number) }

  before { SiteSetting.nested_replies_enabled = true }

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
  end

  describe "#root_posts_scope" do
    it "falls back for stale formulas with reply engagement" do
      engaged_root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      3.times { Fabricate(:post, topic: topic, reply_to_post_number: engaged_root.post_number) }
      root.update_columns(created_at: 1.day.ago)
      engaged_root.update_columns(created_at: root.created_at)
      NestedViewPostStat.find_or_create_by!(post: root).update_columns(
        hot_score: 90,
        thread_hot_score: 90,
        hot_score_updated_at: Time.current,
      )
      formula_field = NestedReplies::HotScoreCalculator::FORMULA_VERSION_FIELD
      TopicCustomField.where(topic: topic, name: formula_field).delete_all
      loader = described_class.new(topic: topic, guardian: user.guardian)

      without_formula = loader.root_posts_scope("hot").limit(2).pluck(:id)
      TopicCustomField.create!(topic: topic, name: formula_field, value: "outdated")
      with_wrong_formula = loader.root_posts_scope("hot").limit(2).pluck(:id)

      expect(without_formula).to eq([engaged_root.id, root.id])
      expect(with_wrong_formula).to eq([engaged_root.id, root.id])
    end
  end
end
