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

    it "reads the first rows of the segment" do
      expect(rows.map(&:record)).to eq([first_topic, second_topic])
    end

    it "reads no more than the page asked for" do
      expect(rows.size).to eq(size)
    end

    it "hands back rows that know where they sit in the listing" do
      expect(rows.first.cursor).to eq(segment.position_of(first_topic).to_cursor)
    end

    context "with a cursor" do
      let(:after) { JsonApiKit::Pagination::Cursor.new([first_topic.id]) }

      it "starts strictly after the row it names" do
        expect(rows.map(&:record)).to eq([second_topic, third_topic])
      end
    end

    context "when the segment holds only some of the rows" do
      let(:segment) do
        JsonApiKit::Pagination::Order::Segment.new(
          id: 3,
          keyset:,
          rows: ->(narrowed) { narrowed.where(id: third_topic.id) },
        )
      end

      it "reads only those" do
        expect(rows.map(&:record)).to eq([third_topic])
      end
    end
  end

  describe "#truncated?" do
    it "knows the segment carries on past the page" do
      expect(scan).to be_truncated
    end

    context "when the page reaches the end of the segment" do
      let(:size) { 3 }

      it "knows it does not" do
        expect(scan).not_to be_truncated
      end
    end

    context "without a page to read, as a probe" do
      let(:size) { 0 }

      it "answers whether the segment holds anything at all" do
        expect(scan).to be_truncated
      end
    end
  end
end
