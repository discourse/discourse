# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Scan do
  subject(:scan) { described_class.new(scope, segment:, size:, after:) }

  fab!(:first_topic, :topic)
  fab!(:second_topic, :topic)
  fab!(:third_topic, :topic)

  let(:model) { Topic }
  let(:keyset) do
    JsonApiKit::Pagination::Keyset.new([JsonApiKit::Pagination::Keyset::Key.new(:id, model:)])
  end
  let(:segment) { JsonApiKit::Pagination::Order::Segment.new(id: 3, keyset:) }
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

    context "when a cursor is present" do
      let(:after) { JsonApiKit::Pagination::Cursor.new([first_topic.id]) }

      it "reads the rows after that row" do
        expect(rows.map(&:record)).to eq([second_topic, third_topic])
      end
    end

    context "when the segment holds only some of the rows" do
      let(:segment) do
        JsonApiKit::Pagination::Order::Segment.new(
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
end
