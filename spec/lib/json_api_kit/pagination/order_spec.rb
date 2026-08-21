# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Order do
  subject(:order) { described_class.new(keyset) }

  fab!(:pinned_topic) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }
  fab!(:unpinned_topic, :topic)

  let(:model) { Topic }
  let(:key) { JsonApiKit::Pagination::Keyset::Key }
  let(:keys) { [key.new(:created_at, model:, direction: :desc), key.new(:id, model:)] }
  let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
  let(:scope) { Topic.where(id: [pinned_topic.id, unpinned_topic.id]) }

  it { is_expected.to delegate_method(:leading).to(:keyset) }
  it { is_expected.to delegate_method(:first).to(:segments) }
  it { is_expected.to delegate_method(:columns).to(:segments) }
  it { is_expected.to delegate_method(:locate).to(:segments) }
  it { is_expected.to delegate_method(:fetch).to(:segments) }
  it { is_expected.to delegate_method(:after).to(:segments) }

  describe "#compatible_with?" do
    let(:cursor) do
      JsonApiKit::Pagination::Cursor.new([0, pinned_topic.created_at, pinned_topic.id])
    end

    it "accepts the cursor" do
      expect(order).to be_compatible_with(cursor:)
    end

    context "when no segment of this order has that id" do
      let(:cursor) { JsonApiKit::Pagination::Cursor.new([7, pinned_topic.created_at, 1]) }

      it "refuses the cursor" do
        expect(order).not_to be_compatible_with(cursor:)
      end
    end

    context "when the cursor holds another number of values" do
      let(:cursor) { JsonApiKit::Pagination::Cursor.new([0, pinned_topic.id]) }

      it "refuses the cursor" do
        expect(order).not_to be_compatible_with(cursor:)
      end
    end
  end

  describe "#split?" do
    context "when the leading key cannot be null" do
      it { is_expected.not_to be_split }
    end

    context "when the leading key can be null" do
      let(:keys) do
        [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
      end

      it { is_expected.to be_split }
    end
  end

  describe "#reverse" do
    subject(:reversed_order) { order.reverse }

    let(:keys) do
      [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
    end

    it "reads its segments in the other sequence" do
      expect(reversed_order.segments.map(&:id)).to eq([1, 0])
    end

    it "keeps each segment id on the rows it holds" do
      expect(reversed_order.first.scope(scope).map(&:id)).to contain_exactly(unpinned_topic.id)
    end
  end

  describe "#enter" do
    subject(:entry_row) { order.enter(scope, at_or_after:) }

    let(:keys) do
      [key.new(:pinned_at, model:, direction: :asc, nulls: :last), key.new(:id, model:)]
    end
    let(:at_or_after) { scope.where("pinned_at >= ?", Time.utc(2026, 7, 1)) }

    it "returns the first row at or after the value" do
      expect(entry_row.record).to eq(pinned_topic)
    end

    context "when no row holds a value for that key" do
      let(:at_or_after) { scope.where("pinned_at >= ?", Time.utc(2030, 1, 1)) }

      it "returns the first row of a later segment" do
        expect(entry_row.record).to eq(unpinned_topic)
      end

      it "places the row in that segment" do
        expect(entry_row.position.segment).to eq(order.segments.last)
      end
    end

    context "when the listing holds no row" do
      let(:scope) { Topic.where(id: -1) }

      it "returns nil" do
        expect(entry_row).to be_nil
      end
    end
  end

  describe "#position" do
    let(:keys) do
      [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
    end
    let(:cursor) { JsonApiKit::Pagination::Cursor.new([1, unpinned_topic.id]) }

    before { allow(JsonApiKit::Pagination::Order::Position).to receive(:from) }

    it "places the cursor in this order" do
      order.position(cursor)

      expect(JsonApiKit::Pagination::Order::Position).to have_received(:from).with(cursor, order:)
    end
  end
end
