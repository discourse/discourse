# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Order::Position do
  subject(:position) { described_class.new(segment:, cursor:) }

  fab!(:topic)

  let(:model) { Topic }
  let(:key) { JsonApiKit::Pagination::Keyset::Key }
  let(:keys) { [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)] }
  let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
  let(:order) { JsonApiKit::Pagination::Order.for(keyset) }
  let(:segment) { order.segment(1) }
  let(:cursor) { JsonApiKit::Pagination::Cursor.new([topic.id]) }

  describe ".from" do
    subject(:position) { described_class.from(wire_cursor, order:) }

    let(:wire_cursor) { JsonApiKit::Pagination::Cursor.new([1, topic.id]) }

    it "resolves the segment the cursor names" do
      expect(position.segment).to eq(order.segment(1))
    end

    it "keeps the rest of the cursor for comparison" do
      expect(position.cursor.values).to eq([topic.id])
    end
  end

  describe "#to_cursor" do
    it "puts the segment ahead of the compared values" do
      expect(position.to_cursor.values).to eq([1, topic.id])
    end
  end

  describe "#in" do
    subject(:in_reverse) { position.in(order.reverse) }

    it "keeps the same segment" do
      expect(in_reverse.segment.id).to eq(segment.id)
    end

    it "takes the directions of the given order" do
      expect(in_reverse.segment.keyset.keys.map(&:direction)).to eq([:desc])
    end
  end
end
