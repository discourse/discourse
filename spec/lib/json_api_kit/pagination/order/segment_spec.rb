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
    subject(:narrowed) { segment.narrowed_by(narrowing).scope(scope).map(&:id) }

    let(:narrowing) { ->(rows) { rows.where(id: [pinned.id, unpinned.id]) } }

    it "keeps only what the narrowing allows" do
      expect(narrowed).to contain_exactly(unpinned.id)
    end

    context "when the narrowing would allow rows the segment does not hold" do
      let(:narrowing) { ->(rows) { rows.where(id: pinned.id) } }

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
      expect(reversed.keyset.keys.map(&:direction)).to eq([:desc])
    end
  end
end
