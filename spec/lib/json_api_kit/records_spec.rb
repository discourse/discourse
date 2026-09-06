# frozen_string_literal: true

RSpec.describe JsonApiKit::Records do
  subject(:page) { described_class.new(held).page(2) }

  let(:record_class) { Struct.new(:record, :cursor) }
  let(:held) { 1.upto(3).map { record_class.new("record #{it}", "cursor #{it}") } }

  describe "#page" do
    it "holds the first records of the collection" do
      expect(page.records.map(&:cursor)).to eq(["cursor 1", "cursor 2"])
    end

    it "returns the cursor the next page starts at" do
      expect(page.cursor).to eq("cursor 2")
    end

    context "when the reading holds no more records than the page" do
      let(:held) { 1.upto(2).map { record_class.new("record #{it}", "cursor #{it}") } }

      it "returns no cursor" do
        expect(page.cursor).to be_nil
      end
    end

    context "when the reading holds fewer records than the page" do
      let(:held) { [record_class.new("record 1", "cursor 1")] }

      it "holds all of them" do
        expect(page.records.map(&:cursor)).to eq(["cursor 1"])
      end
    end
  end

  describe "#fetch_all" do
    subject(:fetched) { described_class.new(held).fetch_all(rows) }

    let(:rows) { ["record 3", "record 1"] }

    it "returns the records those rows name in that order" do
      expect(fetched.map(&:record)).to eq(["record 3", "record 1"])
    end

    context "when a row matches no record" do
      let(:rows) { ["record 1", "nowhere"] }

      it "refuses to answer" do
        expect { fetched }.to raise_error(KeyError)
      end
    end
  end
end
