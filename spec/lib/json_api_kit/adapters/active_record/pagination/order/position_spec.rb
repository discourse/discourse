# frozen_string_literal: true

RSpec.describe JsonApiKit::Adapters::ActiveRecord::Pagination::Order::Position do
  subject(:position) { described_class.new(segment:, values:) }

  fab!(:topic)

  let(:model) { Topic }
  let(:key) { JsonApiKit::Adapters::ActiveRecord::Pagination::Keyset::Key }
  let(:keys) { [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)] }
  let(:keyset) { JsonApiKit::Adapters::ActiveRecord::Pagination::Keyset.new(keys) }
  let(:order) { JsonApiKit::Adapters::ActiveRecord::Pagination::Order.new(keyset) }
  let(:segment) { order.fetch(1) }
  let(:values) { [topic.id] }

  describe ".from" do
    subject(:position) { described_class.from(cursor, order:) }

    let(:cursor) do
      JsonApiKit::Adapters::ActiveRecord::Pagination::Cursor.new([order.digest, 1, topic.id])
    end

    it "returns a position in the segment the cursor names" do
      expect(position.segment).to eq(order.fetch(1))
    end

    it "keeps the values of the cursor" do
      expect(position.values).to eq([topic.id])
    end
  end

  describe ".new" do
    context "when the position has too few values" do
      let(:values) { [] }

      it "reports the expected value count" do
        expect { position }.to raise_error(
          ArgumentError,
          "Incorrect number of values for this order segment: expected 1, received 0.",
        )
      end
    end

    context "when the position has too many values" do
      let(:values) { [topic.pinned_at, topic.id] }

      it "reports the expected value count" do
        expect { position }.to raise_error(
          ArgumentError,
          "Incorrect number of values for this order segment: expected 1, received 2.",
        )
      end
    end
  end

  describe "#to_cursor" do
    it "returns a cursor that starts with the listing and the segment" do
      expect(position.to_cursor.values).to eq([order.digest, 1, topic.id])
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
