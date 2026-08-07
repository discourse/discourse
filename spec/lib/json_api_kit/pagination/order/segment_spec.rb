# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Order::Segment do
  subject(:segment) { described_class.new(id: 1, keyset:, rows:) }

  fab!(:pinned) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }
  fab!(:unpinned, :topic)
  fab!(:other_unpinned, :topic)

  let(:model) { Topic }
  let(:keyset) do
    JsonApiKit::Pagination::Keyset.new([JsonApiKit::Pagination::Keyset::Key.new(:id, model:)])
  end
  let(:rows) { ->(scope) { scope.where(pinned_at: nil) } }
  let(:scope) { Topic.where(id: [pinned.id, unpinned.id, other_unpinned.id]) }

  describe ".split" do
    subject(:segments) { described_class.split(keyset) }

    let(:key) { JsonApiKit::Pagination::Keyset::Key }
    let(:keys) { [key.new(:created_at, model:, direction: :desc), key.new(:id, model:)] }
    let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
    let(:unpinned_ids) { [unpinned.id, other_unpinned.id] }

    it "reads a listing whose keys are never null as one band" do
      expect(segments.size).to eq(1)
    end

    it "holds the whole listing in it" do
      expect(segments.first.scope(scope)).to be(scope)
    end

    context "with a nullable leading key" do
      let(:keys) do
        [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
      end

      it "splits it in two, the valued rows before the null tail" do
        expect(segments.map(&:id)).to eq([0, 1])
      end

      it "keeps the nullable key out of the leading band's nulls" do
        expect(segments.first.scope(scope).map(&:id)).to contain_exactly(pinned.id)
      end

      it "gives the tail the rows the key is null in" do
        expect(segments.last.scope(scope).map(&:id)).to match_array(unpinned_ids)
      end

      it "orders the leading band by the key and then the tiebreak" do
        expect(segments.first.keyset.keys.map(&:name)).to eq(%i[pinned_at id])
      end

      it "drops the key from the tail, where every row shares its one null value" do
        expect(segments.last.keyset.keys.map(&:name)).to eq([:id])
      end

      it "asks for no nulls placement in the valued band, which constrains the index it reads" do
        expect(segments.first.keyset.order.join(" ")).not_to include("NULLS")
      end
    end

    context "with a leading key whose nulls sort first" do
      let(:keys) { [key.new(:pinned_at, model:, nulls: :first), key.new(:id, model:)] }

      it "reads the null band before the valued one" do
        expect(segments.first.scope(scope).map(&:id)).to match_array(unpinned_ids)
      end
    end

    context "with a nullable key and nothing to break its ties" do
      let(:keys) { [key.new(:pinned_at, model:, nulls: :last)] }

      it "refuses the listing, its null rows having no order at all" do
        expect { segments }.to raise_error(ArgumentError)
      end
    end

    context "with a nullable key that does not lead" do
      let(:keys) { [key.new(:created_at, model:), key.new(:pinned_at, model:, nulls: :last)] }

      it "reads it as one band, the leading key's bound doing the seeking" do
        expect(segments.size).to eq(1)
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
        expect(segments.size).to eq(3)
      end

      it "narrows each band further than the one before" do
        expect(segments.map { it.keyset.keys.map(&:name) }).to eq(
          [%i[pinned_at bumped_at id], %i[bumped_at id], %i[id]],
        )
      end
    end
  end

  describe "#scope" do
    subject(:narrowed) { segment.scope(scope) }

    it "keeps only the rows that belong to the segment" do
      expect(narrowed.map(&:id)).to contain_exactly(unpinned.id, other_unpinned.id)
    end

    context "when the segment holds every row of the listing" do
      let(:rows) { described_class::ALL_ROWS }

      it "leaves the scope alone" do
        expect(narrowed).to be(scope)
      end
    end
  end

  describe "#narrowed_by" do
    subject(:narrowed) { segment.narrowed_by(condition).scope(scope).map(&:id) }

    let(:condition) { ->(rows) { rows.where(id: [pinned.id, unpinned.id]) } }

    it "keeps only what the condition allows" do
      expect(narrowed).to contain_exactly(unpinned.id)
    end

    context "when the condition would allow rows the segment does not hold" do
      let(:condition) { ->(rows) { rows.where(id: pinned.id) } }

      it "keeps holding only its own" do
        expect(narrowed).to be_empty
      end
    end
  end

  describe "#position_of" do
    subject(:position) { segment.position_of(unpinned) }

    it "places the row in this segment" do
      expect(position.segment).to eq(segment)
    end

    it "compares it against this segment's own order" do
      expect(position.cursor).to eq(keyset.cursor_for(unpinned))
    end
  end

  describe "#reverse" do
    subject(:reversed) { segment.reverse }

    it "keeps its identity, which is what a cursor names" do
      expect(reversed.id).to eq(1)
    end

    it "keeps the rows it holds" do
      expect(reversed.scope(scope).map(&:id)).to contain_exactly(unpinned.id, other_unpinned.id)
    end

    it "walks its own order backwards" do
      expect(reversed.keyset.keys.map { it.direction.to_sym }).to eq([:desc])
    end
  end
end
