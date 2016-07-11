require 'rails_helper'

describe Tag do
  def make_some_tags(count: 3, tag_a_topic: false)
    @tags = []
    if tag_a_topic
      count.times { |i| @tags << Fabricate(:tag, topics: [Fabricate(:topic)]) }
    else
      count.times { |i| @tags << Fabricate(:tag) }
    end
  end

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.min_trust_level_to_tag_topics = 0
  end

  describe '#tags_by_count_query' do
    it "returns empty hash if nothing is tagged" do
      expect(described_class.tags_by_count_query.count).to eq({})
    end

    context "with some tagged topics" do
      before do
        @topics = []
        3.times { @topics << Fabricate(:topic) }
        make_some_tags(count: 2)
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

  describe '#top_tags' do
    it "returns nothing if nothing has been tagged" do
      make_some_tags(tag_a_topic: false)
      expect(described_class.top_tags.sort).to be_empty
    end

    it "can return all tags" do
      make_some_tags(tag_a_topic: true)
      expect(described_class.top_tags.sort).to eq(@tags.map(&:name).sort)
    end

    context "with category-specific tags" do
      before do
        make_some_tags(count: 3)
        @category1 = Fabricate(:category, tags: [@tags[0]]) # only one tag allowed in this category
        @category2 = Fabricate(:category)
        @topics = []
        @topics << Fabricate(:topic, category: @category1, tags: [@tags[0]])
        @topics << Fabricate(:topic, category: @category2, tags: [@tags[1], @tags[2]])
        @topics << Fabricate(:topic, tags: [@tags[2]]) # uncategorized
      end

      it "for category with restricted tags, lists those tags" do
        expect(described_class.top_tags(category: @category1)).to eq([@tags[0].name])
      end

      it "for category without tags, lists allowed tags" do
        expect(described_class.top_tags(category: @category2).sort).to eq([@tags[1].name, @tags[2].name].sort)
      end

      it "for no category arg, lists all tags" do
        expect(described_class.top_tags.sort).to eq([@tags[0].name, @tags[1].name, @tags[2].name].sort)
      end
    end
  end
end
