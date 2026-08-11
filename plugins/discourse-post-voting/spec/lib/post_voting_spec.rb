# frozen_string_literal: true

RSpec.describe PostVoting do
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:subcategory) { Fabricate(:category, parent_category: category) }

  def set_override(target, value)
    target.upsert_custom_fields(PostVoting::ALLOW_POST_VOTING => value)
    PostVoting.clear_category_overrides_cache(after_commit: false)
  end

  def override_for(target)
    target.reload.custom_fields[PostVoting::ALLOW_POST_VOTING]
  end

  describe ".post_voting_enabled_for?" do
    it "allows every category in all_categories mode, whatever the overrides say" do
      SiteSetting.post_voting_category_mode = "all_categories"
      set_override(category, false)

      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(nil)).to eq(true)
    end

    it "follows the category value in opt_in mode" do
      SiteSetting.post_voting_category_mode = "opt_in"
      set_override(category, true)

      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(other_category.id)).to eq(false)
    end

    it "follows the category value in opt_out mode" do
      SiteSetting.post_voting_category_mode = "opt_out"
      set_override(category, false)

      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(false)
      expect(PostVoting.post_voting_enabled_for?(other_category.id)).to eq(true)
    end

    it "rejects a blank category id unless every category is allowed" do
      SiteSetting.post_voting_category_mode = "opt_in"

      expect(PostVoting.post_voting_enabled_for?(nil)).to eq(false)
      expect(PostVoting.post_voting_enabled_for?("")).to eq(false)
    end

    it "accepts a category id given as a string" do
      SiteSetting.post_voting_category_mode = "opt_in"
      set_override(category, true)

      expect(PostVoting.post_voting_enabled_for?(category.id.to_s)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(other_category.id.to_s)).to eq(false)
    end

    it "picks up a category value change without a restart" do
      SiteSetting.post_voting_category_mode = "opt_in"
      set_override(category, true)

      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)

      set_override(category, false)

      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(false)
    end
  end

  describe "selecting a mode" do
    it "sets every category to not allowed for opt_in" do
      SiteSetting.post_voting_category_mode = "opt_in"

      expect(override_for(category)).to eq(false)
      expect(override_for(subcategory)).to eq(false)
      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(false)
    end

    it "sets every category to allowed for opt_out" do
      SiteSetting.post_voting_category_mode = "opt_out"

      expect(override_for(category)).to eq(true)
      expect(override_for(subcategory)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
    end

    it "resets every category when the mode changes, including ones already set" do
      SiteSetting.post_voting_category_mode = "opt_in"
      set_override(category, true)

      expect(override_for(other_category)).to eq(false)

      SiteSetting.post_voting_category_mode = "opt_out"

      expect(override_for(category)).to eq(true)
      expect(override_for(other_category)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(other_category.id)).to eq(true)
    end

    it "resets back to not allowed when the mode returns to opt_in" do
      SiteSetting.post_voting_category_mode = "opt_out"
      set_override(category, false)

      SiteSetting.post_voting_category_mode = "opt_in"

      expect(override_for(category)).to eq(false)
      expect(override_for(other_category)).to eq(false)
    end

    it "writes nothing while every category is allowed" do
      SiteSetting.post_voting_category_mode = "all_categories"

      expect(override_for(category)).to eq(nil)
    end
  end

  describe "applying to subcategories" do
    fab!(:nested_subcategory) do
      SiteSetting.max_category_nesting = 3
      Fabricate(:category, parent_category: subcategory)
    end

    # Mirrors the controller path: the flag arrives with the save, then
    # `on_custom_fields_change` consumes and discards it.
    def apply_to_subcategories(target)
      target.custom_fields[PostVoting::APPLY_TO_SUBCATEGORIES] = true
      target.save_custom_fields
    end

    before do
      SiteSetting.max_category_nesting = 3
      SiteSetting.post_voting_category_mode = "opt_in"
    end

    it "copies the category's value down the whole tree" do
      set_override(category, true)

      apply_to_subcategories(category)

      expect(override_for(subcategory)).to eq(true)
      expect(override_for(nested_subcategory)).to eq(true)
      expect(override_for(other_category)).to eq(false)
    end

    it "copies a disallowed value down too" do
      set_override(category, true)
      set_override(subcategory, true)
      set_override(category, false)

      apply_to_subcategories(category)

      expect(override_for(subcategory)).to eq(false)
      expect(PostVoting.post_voting_enabled_for?(subcategory.id)).to eq(false)
    end

    it "clears the flag so a later save does not propagate again" do
      set_override(category, true)
      apply_to_subcategories(category)

      expect(override_for(category)).to eq(true)
      expect(category.reload.custom_fields[PostVoting::APPLY_TO_SUBCATEGORIES]).to eq(nil)

      set_override(subcategory, false)
      set_override(category, true)

      expect(override_for(subcategory)).to eq(false)
    end

    it "leaves the category's own value alone" do
      set_override(category, true)

      apply_to_subcategories(category)

      expect(override_for(category)).to eq(true)
    end
  end

  describe "creating a category" do
    it "starts a subcategory from its parent's value" do
      SiteSetting.post_voting_category_mode = "opt_in"
      set_override(category, true)

      fresh_subcategory = Fabricate(:category, parent_category: category)

      expect(override_for(fresh_subcategory)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(fresh_subcategory.id)).to eq(true)
    end

    it "starts a top level category from the mode default" do
      SiteSetting.post_voting_category_mode = "opt_out"

      fresh_category = Fabricate(:category)

      expect(override_for(fresh_category)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(fresh_category.id)).to eq(true)
    end

    it "does not follow the parent once the subcategory has its own value" do
      SiteSetting.post_voting_category_mode = "opt_in"
      set_override(category, true)
      fresh_subcategory = Fabricate(:category, parent_category: category)

      set_override(category, false)

      expect(PostVoting.post_voting_enabled_for?(fresh_subcategory.id)).to eq(true)
    end

    it "writes nothing while every category is allowed" do
      SiteSetting.post_voting_category_mode = "all_categories"

      expect(override_for(Fabricate(:category))).to eq(nil)
    end
  end
end
