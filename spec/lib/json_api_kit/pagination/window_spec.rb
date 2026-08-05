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
  let(:order) { JsonApiKit::Pagination::Order.for(keyset) }
  let(:scope) { Topic.where(id: [first_topic.id, second_topic.id, third_topic.id]) }
  let(:first_position) { order.first.position_of(first_topic) }
  let(:third_position) { order.first.position_of(third_topic) }
  let(:size) { 2 }
  let(:after) { nil }

  describe "#records" do
    it "reads a page of the listing" do
      expect(window.records).to eq([first_topic, second_topic])
    end
  end

  describe "#rows" do
    context "when every segment it read was empty" do
      let(:after) { third_position }

      it "reads none" do
        expect(window.rows).to be_empty
      end
    end
  end

  context "with a listing read in segments" do
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
      it "keeps each row in the segment it was read from, across the spill" do
        expect(window.rows.map { it.position.segment.id }).to eq([0, 0, 1])
      end
    end

    describe "#records" do
      subject(:records) { window.records }

      it "spills out of one segment into the next to fill the page" do
        expect(records).to eq([pinned_late, pinned_early, first_topic])
      end

      context "when the page runs out of rows in the segment it started in" do
        before { allow(JsonApiKit::Pagination::Scan).to receive(:new).and_call_original }

        it "asks the next segment for only the rows the page is still missing" do
          window.records

          expect(JsonApiKit::Pagination::Scan).to have_received(:new).with(
            scope,
            a_hash_including(segment: order.segments.last, size: 1),
          )
        end

        it "reads that segment from its beginning, not from the cursor it arrived with" do
          window.records

          expect(JsonApiKit::Pagination::Scan).to have_received(:new).with(
            scope,
            a_hash_including(segment: order.segments.last, after: nil),
          )
        end
      end

      context "with a cursor inside the leading segment" do
        let(:after) { order.first.position_of(pinned_late) }

        it "reads on from there, across the boundary" do
          expect(records).to eq([pinned_early, first_topic, second_topic])
        end
      end

      context "with a cursor inside the second segment" do
        let(:after) { order.segments.last.position_of(first_topic) }

        it "stays in that segment" do
          expect(records).to eq([second_topic, third_topic])
        end
      end
    end

    describe "#truncated?" do
      context "when the page ends exactly where a segment does" do
        let(:first_position) { order.first.position_of(first_topic) }
        let(:third_position) { order.first.position_of(third_topic) }
        let(:size) { 2 }

        it "knows the listing carries on in the segment after it" do
          expect(window).to be_truncated
        end
      end

      context "when the page ends with the last segment" do
        let(:size) { 5 }

        it "knows nothing follows it" do
          expect(window).not_to be_truncated
        end
      end
    end
  end
end
