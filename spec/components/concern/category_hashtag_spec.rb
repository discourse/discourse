# frozen_string_literal: true

require 'rails_helper'

describe CategoryHashtag do
  describe '#query_from_hashtag_slug' do
    fab!(:parent_category) { Fabricate(:category) }
    fab!(:child_category) { Fabricate(:category, parent_category: parent_category) }

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

    it "should return nil for a non-existent root and a parent subcategory" do
      expect(Category.query_from_hashtag_slug("non-existent#{CategoryHashtag::SEPARATOR}#{parent_category.slug}")).to eq(nil)
    end

    it "should be case sensitive" do
      parent_category.update!(slug: "ApPlE")
      child_category.update!(slug: "OraNGE")

      expect(Category.query_from_hashtag_slug("apple")).to eq(nil)
      expect(Category.query_from_hashtag_slug("apple#{CategoryHashtag::SEPARATOR}orange")).to eq(nil)
    end
  end
end
