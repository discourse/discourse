require 'rails_helper'

describe Tag do
  describe '#tags_by_count_query' do
    it "returns empty hash if nothing is tagged" do
      expect(described_class.tags_by_count_query.count).to eq({})
    end

    context "with some tagged topics" do
      before do
        @topics = []
        @tags = []
        3.times { @topics << Fabricate(:topic) }
        2.times { @tags << Fabricate(:tag) }
        @topics[0].tags << @tags[0]
        @topics[0].tags << @tags[1]
        @topics[1].tags << @tags[0]
      end

      it "returns tag names with topic counts in a hash" do
        counts = described_class.tags_by_count_query.count
        expect(counts[@tags[0].name]).to eq(2)
        expect(counts[@tags[1].name]).to eq(1)
      end

      it "can be used to filter before doing the count" do
        counts = described_class.tags_by_count_query.where("topics.id = ?", @topics[1].id).count
        expect(counts).to eq({@tags[0].name => 1})
      end
    end
  end
end
