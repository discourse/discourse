# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::NumberedRows do
  subject(:numbered_rows) { described_class.new(scope, owner_key: :topic_id, keyset:, size:) }

  fab!(:topic)
  fab!(:other_topic, :topic)
  fab!(:posts) { 3.times.map { Fabricate(:post, topic:) } }
  fab!(:other_posts) { 3.times.map { Fabricate(:post, topic: other_topic) } }

  let(:key) { JsonApiKit::Pagination::Keyset::Key }
  let(:keys) { [key.new(:post_number, model: Post), key.new(:id, model: Post)] }
  let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
  let(:scope) { Post.where(topic_id: [topic.id, other_topic.id]) }
  let(:size) { 1 }

  describe "#bounded_scope" do
    subject(:records) { numbered_rows.bounded_scope.to_a }

    let(:post_numbers) do
      records.group_by(&:topic_id).transform_values { it.map(&:post_number).sort }
    end

    it "reads one row more than the page holds, for each owner" do
      expect(post_numbers).to eq(topic.id => [1, 2], other_topic.id => [1, 2])
    end

    it "leaves the row number out of the rows it reads" do
      expect(records.first.attributes).not_to have_key(described_class::ROW_NUMBER)
    end

    context "when the scope selects two columns" do
      let(:scope) { Post.where(topic_id: [topic.id, other_topic.id]).select(:id, :topic_id) }

      it "reads those columns only" do
        expect(records.first.attributes.keys).to eq(%w[id topic_id])
      end
    end
  end
end
