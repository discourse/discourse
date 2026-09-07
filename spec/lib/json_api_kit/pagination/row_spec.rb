# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Row do
  subject(:row) { described_class.new(record: topic, segment:) }

  fab!(:topic)

  let(:model) { Topic }
  let(:keyset) do
    JsonApiKit::Pagination::Keyset.new([JsonApiKit::Pagination::Keyset::Key.new(:id, model:)])
  end
  let(:segment) { JsonApiKit::Pagination::Order::Segment.new(id: 2, keyset:) }

  describe "#record" do
    it "returns the record it holds" do
      expect(row.record).to eq(topic)
    end
  end

  describe "#position" do
    it "places the record in its own segment" do
      expect(row.position.segment).to be(segment)
    end
  end

  describe "#cursor" do
    before { allow(row.position).to receive(:to_cursor).and_return("THE CURSOR") }

    it "returns the cursor of its position" do
      expect(row.cursor).to eq("THE CURSOR")
    end
  end
end
