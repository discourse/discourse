# frozen_string_literal: true

RSpec.describe JsonApiKit::Adapters::ActiveRecord::Pagination::Scan do
  subject(:scan) { described_class.new(scope, segment:, size:, after:) }

  fab!(:first_topic, :topic)
  fab!(:second_topic, :topic)
  fab!(:third_topic, :topic)

  let(:model) { Topic }
  let(:keyset) do
    JsonApiKit::Adapters::ActiveRecord::Pagination::Keyset.new(
      [JsonApiKit::Adapters::ActiveRecord::Pagination::Keyset::Key.new(:id, model:)],
    )
  end
  let(:segment) do
    JsonApiKit::Adapters::ActiveRecord::Pagination::Order::Segment.new(id: 3, keyset:)
  end
  let(:scope) { Topic.where(id: [first_topic.id, second_topic.id, third_topic.id]) }
  let(:size) { 2 }
  let(:after) { nil }

  describe "#rows" do
    subject(:rows) { scan.rows }

    it "reads the rows from the start of the segment" do
      expect(rows.map(&:record)).to eq([first_topic, second_topic])
    end

    it "reads no more rows than the page holds" do
      expect(rows.size).to eq(size)
    end

    it "places each row in the segment it reads" do
      expect(rows.map { it.position.segment }).to all(be(segment))
    end

    context "when the scan starts after a row" do
      let(:after) { [first_topic.id] }

      it "reads the rows that follow it" do
        expect(rows.map(&:record)).to eq([second_topic, third_topic])
      end
    end

    context "when the segment holds only some of the rows" do
      let(:segment) do
        JsonApiKit::Adapters::ActiveRecord::Pagination::Order::Segment.new(
          id: 3,
          keyset:,
          condition: ->(scope) { scope.where(id: third_topic.id) },
        )
      end

      it "reads only the rows the segment holds" do
        expect(rows.map(&:record)).to eq([third_topic])
      end
    end
  end

  describe "#truncated?" do
    it "reports that more rows follow the page" do
      expect(scan).to be_truncated
    end

    context "when the page reads the last row of the segment" do
      let(:size) { 3 }

      it "reports that no row follows the page" do
        expect(scan).not_to be_truncated
      end
    end

    context "when the page holds no row" do
      let(:size) { 0 }

      it "reports that the segment holds a row" do
        expect(scan).to be_truncated
      end
    end
  end

  describe "#next_in" do
    subject(:next_scan) { scan.next_in(order) }

    fab!(:pinned_topic) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }

    let(:keyset) do
      JsonApiKit::Adapters::ActiveRecord::Pagination::Keyset.new(
        [
          JsonApiKit::Adapters::ActiveRecord::Pagination::Keyset::Key.new(
            :pinned_at,
            model:,
            direction: :desc,
            nulls: :last,
          ),
          JsonApiKit::Adapters::ActiveRecord::Pagination::Keyset::Key.new(:id, model:),
        ],
      )
    end
    let(:order) { JsonApiKit::Adapters::ActiveRecord::Pagination::Order.new(keyset) }
    let(:segment) { order.first }
    let(:scope) { super().or(Topic.where(id: pinned_topic.id)) }
    let(:next_records) { next_scan.rows.map(&:record) }

    it "reads the remaining page capacity from the next segment" do
      expect(next_records).to eq([first_topic])
    end

    context "when the scan has more rows than the page holds" do
      let(:size) { 0 }

      it "returns no next scan" do
        expect(next_scan).to be_nil
      end
    end

    context "when the scan exhausts the last segment" do
      let(:segment) { order.segments.last }
      let(:size) { 3 }

      it "returns no next scan" do
        expect(next_scan).to be_nil
      end
    end

    context "when the cursor skips the first segment" do
      let(:after) { segment.position_of(pinned_topic).values }

      it "reads the next segment from its start" do
        expect(next_records).to eq([first_topic, second_topic])
      end
    end
  end
end
