# frozen_string_literal: true

RSpec.describe CategoryHashtag do
  describe "#query_from_hashtag_slug" do
    fab!(:parent_category) { Fabricate(:category) }
    fab!(:child_category) { Fabricate(:category, parent_category: parent_category) }

    it "should return the right result for a parent category slug" do
      expect(Category.query_from_hashtag_slug(parent_category.slug)).to eq(parent_category)
    end

    it "should return the right result for a parent and child category slug" do
      expect(
        Category.query_from_hashtag_slug(
          "#{parent_category.slug}#{CategoryHashtag::SEPARATOR}#{child_category.slug}",
        ),
      ).to eq(child_category)
    end

    it "should return nil for incorrect parent category slug" do
      expect(Category.query_from_hashtag_slug("random-slug")).to eq(nil)
    end

    it "should return nil for incorrect parent and child category slug" do
      expect(
        Category.query_from_hashtag_slug("random-slug#{CategoryHashtag::SEPARATOR}random-slug"),
      ).to eq(nil)
    end

    it "should return nil for a non-existent root and a parent subcategory" do
      expect(
        Category.query_from_hashtag_slug(
          "non-existent#{CategoryHashtag::SEPARATOR}#{parent_category.slug}",
        ),
      ).to eq(nil)
    end

    context "with multi-level categories" do
      before { SiteSetting.max_category_nesting = 3 }

      it "should return the right result for a grand child category slug" do
        category = Fabricate(:category, parent_category: child_category)
        expect(
          Category.query_from_hashtag_slug(
            "#{child_category.slug}#{CategoryHashtag::SEPARATOR}#{category.slug}",
          ),
        ).to eq(category)
      end
    end
  end
end
