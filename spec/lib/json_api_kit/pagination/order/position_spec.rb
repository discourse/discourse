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

    it "is in the segment the cursor names first" do
      expect(position.segment).to eq(order.segment(1))
    end

    it "compares against the values behind that name" do
      expect(position.cursor.values).to eq([topic.id])
    end
  end

  describe "#to_cursor" do
    it "names the segment before the values, so a client is handed back to the same band" do
      expect(position.to_cursor.values).to eq([1, topic.id])
    end
  end

  describe "#in" do
    subject(:in_reverse) { position.in(order.reverse) }

    it "is the same band of the listing" do
      expect(in_reverse.segment.id).to eq(segment.id)
    end

    it "is compared the way that reading of the listing orders it" do
      expect(in_reverse.segment.keyset.keys.map(&:direction)).to eq([:desc])
    end
  end
end
