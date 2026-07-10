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
  end
end
