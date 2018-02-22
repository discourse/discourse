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

  let(:tag) { Fabricate(:tag) }
  let(:topic) { Fabricate(:topic, tags: [tag]) }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.min_trust_level_to_tag_topics = 0
  end

  it "can delete tags on deleted topics" do
    topic.trash!
    expect { tag.destroy }.to change { Tag.count }.by(-1)
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

    context "with categories" do
      before do
        make_some_tags(count: 4) # one tag that isn't used
        @category1 = Fabricate(:category)
        @private_category = Fabricate(:category)
        @private_category.set_permissions(admins: :full)
        @private_category.save!
        @topics = []
        @topics << Fabricate(:topic, category: @category1, tags: [@tags[0]])
        @topics << Fabricate(:topic, tags: [@tags[1]])
        @topics << Fabricate(:topic, category: @private_category, tags: [@tags[2]])
      end

      it "doesn't return tags that have only been used in private category to anon" do
        expect(described_class.top_tags.sort).to eq([@tags[0].name, @tags[1].name].sort)
      end

      it "returns tags used in private category to those who can see that category" do
        expect(described_class.top_tags(guardian: Guardian.new(Fabricate(:admin))).sort).to eq([@tags[0].name, @tags[1].name, @tags[2].name].sort)
      end

      it "returns tags scoped to a given category" do
        expect(described_class.top_tags(category: @category1).sort).to eq([@tags[0].name].sort)
        expect(described_class.top_tags(category: @private_category, guardian: Guardian.new(Fabricate(:admin))).sort).to eq([@tags[2].name].sort)
      end

      it "returns tags from sub-categories too" do
        sub_category = Fabricate(:category, parent_category_id: @category1.id)
        Fabricate(:topic, category: sub_category, tags: [@tags[1]])
        expect(described_class.top_tags(category: @category1).sort).to eq([@tags[0].name, @tags[1].name].sort)
      end

      it "returns nothing if category arg is private to you" do
        expect(described_class.top_tags(category: @private_category)).to be_empty
      end
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

  context "topic counts" do
    it "should exclude private message topics" do
      topic
      Fabricate(:private_message_topic, tags: [tag])
      described_class.ensure_consistency!
      tag.reload
      expect(tag.topic_count).to eq(1)
    end
  end
end
