# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Order do
  subject(:order) { described_class.for(keyset) }

  fab!(:pinned) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }
  fab!(:unpinned, :topic)

  let(:model) { Topic }
  let(:key) { JsonApiKit::Pagination::Keyset::Key }
  let(:keys) { [key.new(:created_at, model:, direction: :desc), key.new(:id, model:)] }
  let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
  let(:scope) { Topic.where(id: [pinned.id, unpinned.id]) }

  describe ".for" do
    let(:keys) do
      [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
    end

    it "reads the listing as the bands its keyset splits into" do
      expect(order.segments.map(&:id)).to eq([0, 1])
    end
  end

  describe "#after" do
    subject(:following) { order.after(order.first) }

    let(:keys) do
      [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
    end

    it "is the segment a page spills into" do
      expect(following.id).to eq(1)
    end

    context "when asked from the last segment of the listing" do
      subject(:following) { order.after(order.segments.last) }

      it "is nothing" do
        expect(following).to be_nil
      end
    end
  end

  describe "#segment" do
    let(:keys) do
      [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
    end

    it "finds a segment by the identity a cursor names" do
      expect(order.segment(1).id).to eq(1)
    end

    context "with an identity no segment answers to" do
      it "rejects it as it would any unusable cursor" do
        expect { order.segment(7) }.to raise_error(JsonApiKit::Pagination::Cursor::Invalid)
      end
    end
  end

  describe "#reverse" do
    subject(:reversed) { order.reverse }

    let(:keys) do
      [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
    end

    it "reads the segments the other way round, tail first" do
      expect(reversed.segments.map(&:id)).to eq([1, 0])
    end

    it "keeps each segment's identity, so a cursor still names the same rows" do
      expect(reversed.first.scope(scope).map(&:id)).to contain_exactly(unpinned.id)
    end
  end

  describe "#locate" do
    subject(:located) { order.locate(scope, condition:) }

    let(:keys) do
      [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
    end
    let(:condition) { ->(rows) { rows.where(id: unpinned.id) } }

    it "finds the row a condition keeps" do
      expect(located.record).to eq(unpinned)
    end

    it "places it in the segment that holds it" do
      expect(located.position.segment).to eq(order.segments.last)
    end

    context "with a row in the leading segment" do
      let(:condition) { ->(rows) { rows.where(id: pinned.id) } }

      it "places it there instead" do
        expect(located.position.segment).to eq(order.first)
      end
    end

    context "with a condition that keeps rows in both segments" do
      let(:condition) { ->(rows) { rows.where(id: [pinned.id, unpinned.id]) } }

      it "finds the first of them the listing reads" do
        expect(located.record).to eq(pinned)
      end
    end

    context "with a condition that keeps nothing" do
      let(:condition) { ->(rows) { rows.where(id: -1) } }

      it "finds nothing, leaving what to say about it to the caller" do
        expect(located).to be_nil
      end
    end
  end

  describe "#position" do
    subject(:position) { order.position(cursor) }

    let(:keys) do
      [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
    end
    let(:cursor) { JsonApiKit::Pagination::Cursor.new([1, unpinned.id]) }

    it "is in the segment the cursor names" do
      expect(position.segment).to eq(order.segment(1))
    end

    it "carries the values that segment's own order compares against" do
      expect(position.cursor.values).to eq([unpinned.id])
    end
  end
end
