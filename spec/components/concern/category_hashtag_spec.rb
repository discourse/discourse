require 'rails_helper'

describe CategoryHashtag do
  describe '#query_from_hashtag_slug' do
    let(:parent_category) { Fabricate(:category) }
    let(:child_category) { Fabricate(:category, parent_category: parent_category) }

    it "should return the right result for a parent category slug" do
      expect(Category.query_from_hashtag_slug(parent_category.slug))
        .to eq(parent_category)
    end

    it "should return the right result for a parent and child category slug" do
      expect(Category.query_from_hashtag_slug("#{parent_category.slug}#{CategoryHashtag::SEPARATOR}#{child_category.slug}"))
        .to eq(child_category)
    end

    it "should return nil for incorrect parent category slug" do
      expect(Category.query_from_hashtag_slug("random-slug")).to eq(nil)
    end

    it "should return nil for incorrect parent and child category slug" do
      expect(Category.query_from_hashtag_slug("random-slug#{CategoryHashtag::SEPARATOR}random-slug")).to eq(nil)
    end
  end
end
