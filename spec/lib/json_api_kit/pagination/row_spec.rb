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
    it "is the row itself, for whoever renders it" do
      expect(row.record).to eq(topic)
    end
  end

  describe "#position" do
    it "is where the row sits in the listing" do
      expect(row.position.segment).to eq(segment)
    end
  end

  describe "#cursor" do
    it "names that place, for a client to page from" do
      expect(row.cursor).to eq(segment.position_of(topic).to_cursor)
    end
  end
end
