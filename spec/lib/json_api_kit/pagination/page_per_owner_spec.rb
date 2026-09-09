# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::PagePerOwner do
  subject(:page) { described_class.new(scope, order:, size: 2, owner_key: :topic_id) }

  fab!(:topic)
  fab!(:posts) { 3.times.map { Fabricate(:post, topic:) } }

  let(:key) { JsonApiKit::Pagination::Keyset::Key }
  let(:keys) { [key.new(:post_number, model: Post), key.new(:id, model: Post)] }
  let(:order) { JsonApiKit::Pagination::Order.new(JsonApiKit::Pagination::Keyset.new(keys)) }
  let(:scope) { Post.where(topic_id: topic.id) }

  describe ".new" do
    context "when the leading key can be null" do
      let(:keys) { [key.new(:deleted_at, model: Post, nulls: :last), key.new(:id, model: Post)] }

      it "refuses the order" do
        expect { page }.to raise_error(described_class::SplitOrder)
      end
    end
  end

  describe "#rows" do
    it "reads one row more than the page holds" do
      expect(page.rows.map(&:record)).to eq(posts)
    end

    it "reads the rows in the order of the listing" do
      expect(page.rows.map { it.record.post_number }).to eq([1, 2, 3])
    end
  end

  describe "#next" do
    it "returns no cursor" do
      expect(page.next).to be_nil
    end
  end

  describe "#previous" do
    it "returns no cursor" do
      expect(page.previous).to be_nil
    end
  end
end
