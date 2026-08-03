# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Order::Position do
  subject(:position) { described_class.new(segment:, cursor:) }

  fab!(:topic)

  let(:model) { Topic }
  let(:key) { JsonApiKit::Pagination::Keyset::Key }
  let(:keys) { [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)] }
  let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
  let(:order) { JsonApiKit::Pagination::Order.new(keyset) }
  let(:segment) { order.fetch(1) }
  let(:cursor) { JsonApiKit::Pagination::Cursor.new([topic.id]) }

  describe ".from" do
    subject(:position) { described_class.from(wire_cursor, order:) }

    let(:wire_cursor) { JsonApiKit::Pagination::Cursor.new([1, topic.id]) }

    it "returns a position in the cursor's segment" do
      expect(position.segment).to eq(order.fetch(1))
    end

    it "keeps the other values of the cursor" do
      expect(position.cursor.values).to eq([topic.id])
    end
  end

  describe ".new" do
    context "when the cursor holds fewer values than the segment compares" do
      let(:cursor) { JsonApiKit::Pagination::Cursor.new([]) }

      it "refuses the cursor" do
        expect { position }.to raise_error(ArgumentError)
      end
    end

    context "when the cursor holds more values than the segment compares" do
      let(:cursor) { JsonApiKit::Pagination::Cursor.new([topic.pinned_at, topic.id]) }

      it "refuses the cursor" do
        expect { position }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#to_cursor" do
    it "returns a cursor that starts with the id of the segment" do
      expect(position.to_cursor.values).to eq([1, topic.id])
    end
  end

  describe "#in" do
    subject(:in_reverse) { position.in(order.reverse) }

    it "keeps the same segment id" do
      expect(in_reverse.segment.id).to eq(segment.id)
    end

    it "takes the directions of the other order" do
      expect(in_reverse.segment.keyset.keys.map { it.direction.to_sym }).to eq([:desc])
    end
  end
end
