# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Window do
  subject(:window) { described_class.new(scope, order:, size:, after:) }

  fab!(:first_topic, :topic)
  fab!(:second_topic, :topic)
  fab!(:third_topic, :topic)

  let(:model) { Topic }
  let(:key) { JsonApiKit::Pagination::Keyset::Key }
  let(:keys) { [key.new(:id, model:)] }
  let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
  let(:order) { JsonApiKit::Pagination::Order.new(keyset) }
  let(:scope) { Topic.where(id: [first_topic.id, second_topic.id, third_topic.id]) }
  let(:third_position) { order.first.position_of(third_topic) }
  let(:size) { 2 }
  let(:after) { nil }

  describe "#rows" do
    subject(:records) { window.rows.map(&:record) }

    it "reads the first rows of the listing" do
      expect(records).to eq([first_topic, second_topic])
    end

    context "when the cursor sits on the last row" do
      let(:after) { third_position }

      it "reads no row" do
        expect(records).to be_empty
      end
    end
  end

  describe "#truncated?" do
    it "reports that more rows follow the page" do
      expect(window).to be_truncated
    end

    context "when the page ends with the last row of the listing" do
      let(:size) { 3 }

      it "reports that no row follows the page" do
        expect(window).not_to be_truncated
      end
    end
  end

  context "when the order reads the listing in segments" do
    fab!(:pinned_late) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 2)) }
    fab!(:pinned_early) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }

    let(:keys) do
      [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
    end
    let(:scope) do
      Topic.where(
        id: [pinned_late.id, pinned_early.id, first_topic.id, second_topic.id, third_topic.id],
      )
    end
    let(:size) { 3 }

    describe "#rows" do
      subject(:records) { window.rows.map(&:record) }

      it "reads on into the next segment to fill the page" do
        expect(records).to eq([pinned_late, pinned_early, first_topic])
      end

      it "places each row in the segment it comes from" do
        expect(window.rows.map { it.position.segment.id }).to eq([0, 0, 1])
      end

      context "when the page needs more rows than the segment holds" do
        before { allow(JsonApiKit::Pagination::Scan).to receive(:new).and_call_original }

        it "asks the next segment for only the rows the page still needs" do
          window.rows

          expect(JsonApiKit::Pagination::Scan).to have_received(:new).with(
            scope,
            a_hash_including(segment: order.segments.last, size: 1),
          )
        end

        it "reads that segment from its start" do
          window.rows

          expect(JsonApiKit::Pagination::Scan).to have_received(:new).with(
            scope,
            a_hash_including(segment: order.segments.last, after: nil),
          )
        end
      end

      context "when the cursor sits in the leading segment" do
        let(:after) { order.first.position_of(pinned_late) }

        it "reads on from there into the next segment" do
          expect(records).to eq([pinned_early, first_topic, second_topic])
        end
      end

      context "when the cursor sits in the second segment" do
        let(:after) { order.segments.last.position_of(first_topic) }

        it "stays in that segment" do
          expect(records).to eq([second_topic, third_topic])
        end
      end
    end

    describe "#truncated?" do
      context "when the page ends where a segment ends" do
        let(:size) { 2 }

        it "reports that more rows follow the page" do
          expect(window).to be_truncated
        end
      end

      context "when the page ends with the last segment" do
        let(:size) { 5 }

        it "reports that no row follows the page" do
          expect(window).not_to be_truncated
        end
      end
    end
  end
end
