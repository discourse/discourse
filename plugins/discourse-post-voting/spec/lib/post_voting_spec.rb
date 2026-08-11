# frozen_string_literal: true

RSpec.describe PostVoting do
  fab!(:category)
  fab!(:other_category, :category)

  describe ".post_voting_enabled_for?" do
    it "allows every category when no categories are configured" do
      SiteSetting.post_voting_enabled_categories = ""

      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(nil)).to eq(true)
    end

    it "allows only the configured categories" do
      SiteSetting.post_voting_enabled_categories = category.id.to_s

      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(other_category.id)).to eq(false)
    end

    it "accepts a category id given as a string" do
      SiteSetting.post_voting_enabled_categories = category.id.to_s

      expect(PostVoting.post_voting_enabled_for?(category.id.to_s)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(other_category.id.to_s)).to eq(false)
    end

    it "rejects a blank category id when categories are configured" do
      SiteSetting.post_voting_enabled_categories = category.id.to_s

      expect(PostVoting.post_voting_enabled_for?(nil)).to eq(false)
      expect(PostVoting.post_voting_enabled_for?("")).to eq(false)
    end

    it "rejects a subcategory of a configured category by default" do
      subcategory = Fabricate(:category, parent_category: category)
      SiteSetting.post_voting_enabled_categories = category.id.to_s

      expect(PostVoting.post_voting_enabled_for?(subcategory.id)).to eq(false)
    end

    it "allows descendants of a configured category when subcategories are included" do
      SiteSetting.max_category_nesting = 3
      subcategory = Fabricate(:category, parent_category: category)
      nested_subcategory = Fabricate(:category, parent_category: subcategory)
      SiteSetting.post_voting_enabled_categories = category.id.to_s
      SiteSetting.post_voting_enabled_categories_include_subcategories = true

      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(subcategory.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(nested_subcategory.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(other_category.id)).to eq(false)
    end

    it "allows every category when subcategories are included but none are configured" do
      SiteSetting.post_voting_enabled_categories = ""
      SiteSetting.post_voting_enabled_categories_include_subcategories = true

      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(nil)).to eq(true)
    end

    it "picks up a change to the setting" do
      SiteSetting.post_voting_enabled_categories = category.id.to_s

      expect(PostVoting.post_voting_enabled_for?(other_category.id)).to eq(false)

      SiteSetting.post_voting_enabled_categories = "#{category.id}|#{other_category.id}"

      expect(PostVoting.post_voting_enabled_for?(other_category.id)).to eq(true)
    end
  end
end
