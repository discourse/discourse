# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Order::Segments do
  subject(:segments) { described_class.for(keyset) }

  fab!(:pinned_topic) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }
  fab!(:unpinned_topic, :topic)

  let(:model) { Topic }
  let(:key) { JsonApiKit::Pagination::Keyset::Key }
  let(:keys) { [key.new(:pinned_at, model:, direction: :asc, nulls: :last), key.new(:id, model:)] }
  let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
  let(:scope) { Topic.where(id: [pinned_topic.id, unpinned_topic.id]) }

  describe "#fetch" do
    it "returns the segment with that id" do
      expect(segments.fetch(1)).to eq(segments.last)
    end

    context "when no segment has that id" do
      it "refuses the id" do
        expect { segments.fetch(9) }.to raise_error(KeyError)
      end
    end
  end

  describe "#after" do
    subject(:later_segments) { segments.after(segments.first) }

    it "returns the segments that follow it" do
      expect(later_segments.map(&:id)).to eq([1])
    end

    context "when no segment follows it" do
      subject(:later_segments) { segments.after(segments.last) }

      it { is_expected.to be_empty }
    end
  end

  describe "#after_every_value_of" do
    it "returns the segments after the one that holds values for the key" do
      expect(segments.after_every_value_of(:pinned_at).map(&:id)).to eq([1])
    end
  end

  describe "#locate" do
    let(:located_row) { segments.locate(rows) }
    let(:rows) { scope }

    it "returns the first row the listing reads" do
      expect(located_row.record).to eq(pinned_topic)
    end

    it "places the row in the segment that holds it" do
      expect(located_row.position.segment).to eq(segments.first)
    end

    context "when only a later segment holds a row" do
      let(:rows) { scope.where(id: unpinned_topic.id) }

      it "places the row in that segment" do
        expect(located_row.position.segment).to eq(segments.last)
      end
    end

    context "when no segment holds a row" do
      let(:rows) { scope.where(id: -1) }

      it "returns nil" do
        expect(located_row).to be_nil
      end
    end
  end

  describe "#columns" do
    it "returns the columns of every segment, each one once" do
      expect(segments.columns).to eq(%i[pinned_at id])
    end
  end
end
