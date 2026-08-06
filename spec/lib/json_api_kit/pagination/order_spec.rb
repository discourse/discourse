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
    it "reads a listing whose keys are never null as one segment" do
      expect(order.segments.size).to eq(1)
    end

    it "holds the whole listing in that segment" do
      expect(order.first.scope(scope)).to be(scope)
    end

    context "with a nullable leading key" do
      let(:keys) do
        [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
      end

      it "splits the listing in two, the valued rows before the null tail" do
        expect(order.segments.map(&:id)).to eq([0, 1])
      end

      it "keeps the nullable key out of the leading segment's nulls" do
        expect(order.first.scope(scope).map(&:id)).to contain_exactly(pinned.id)
      end

      it "gives the tail the rows the key is null in" do
        expect(order.segments.last.scope(scope).map(&:id)).to contain_exactly(unpinned.id)
      end

      it "orders the leading segment by the key and then the tiebreak" do
        expect(order.first.keyset.keys.map(&:name)).to eq(%i[pinned_at id])
      end

      it "drops the key from the tail, where every row shares its one null value" do
        expect(order.segments.last.keyset.keys.map(&:name)).to eq([:id])
      end

      it "asks for no nulls placement in the valued band, which constrains the index it reads" do
        expect(order.first.keyset.order.join(" ")).not_to include("NULLS")
      end
    end

    context "with a leading key whose nulls sort first" do
      let(:keys) { [key.new(:pinned_at, model:, nulls: :first), key.new(:id, model:)] }

      it "reads the null band before the valued one" do
        expect(order.first.scope(scope).map(&:id)).to contain_exactly(unpinned.id)
      end
    end

    context "with a nullable key and nothing to break its ties" do
      let(:keys) { [key.new(:pinned_at, model:, nulls: :last)] }

      it "refuses the listing, its null rows having no order at all" do
        expect { order }.to raise_error(ArgumentError)
      end
    end

    context "with a nullable key that does not lead" do
      let(:keys) { [key.new(:created_at, model:), key.new(:pinned_at, model:, nulls: :last)] }

      it "reads it as one segment, the leading key's bound doing the seeking" do
        expect(order.segments.size).to eq(1)
      end
    end

    context "with two nullable keys leading" do
      let(:keys) do
        [
          key.new(:pinned_at, model:, nulls: :last),
          key.new(:bumped_at, model:, nulls: :last),
          key.new(:id, model:),
        ]
      end

      it "splits again inside the tail" do
        expect(order.segments.size).to eq(3)
      end

      it "narrows each segment further than the one before" do
        expect(order.segments.map { it.keyset.keys.map(&:name) }).to eq(
          [%i[pinned_at bumped_at id], %i[bumped_at id], %i[id]],
        )
      end
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
    subject(:located) { order.locate(scope, matching:) }

    let(:keys) do
      [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
    end
    let(:matching) { ->(rows) { rows.where(id: unpinned.id) } }

    it "finds the row a narrowing keeps" do
      expect(located.record).to eq(unpinned)
    end

    it "places it in the segment that holds it" do
      expect(located.position.segment).to eq(order.segments.last)
    end

    context "with a row in the leading segment" do
      let(:matching) { ->(rows) { rows.where(id: pinned.id) } }

      it "places it there instead" do
        expect(located.position.segment).to eq(order.first)
      end
    end

    context "with a narrowing that keeps rows in both segments" do
      let(:matching) { ->(rows) { rows.where(id: [pinned.id, unpinned.id]) } }

      it "finds the first of them the listing reads" do
        expect(located.record).to eq(pinned)
      end
    end

    context "with a narrowing that keeps nothing" do
      let(:matching) { ->(rows) { rows.where(id: -1) } }

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
