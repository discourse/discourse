# frozen_string_literal: true

describe "Tag synonyms", type: :system, js: true do
  let(:tags_page) { PageObjects::Pages::Tag.new }
  fab!(:tag_1) { Fabricate(:tag, name: "design") }
  fab!(:tag_2) { Fabricate(:tag, name: "art") }
  fab!(:current_user) { Fabricate(:admin) }

  before { sign_in(current_user) }

  describe "when visiting edit tag page" do
    it "allows an admin to add existing tag as a synonym" do
      tags_page.visit_tag(tag_1)

      expect(tags_page.tag_info_btn).to be_visible
      tags_page.tag_info_btn.click

      expect(tags_page.edit_synonyms_btn).to be_visible
      tags_page.edit_synonyms_btn.click

      expect(tags_page.add_synonyms_select_field).to be_visible
      tags_page.add_synonyms_select_field.click

      expect(tags_page.has_search_result?(tag_2.name)).to be_truthy
      tags_page.search_result(1).click

      expect(tags_page.add_synonym_btn).to be_visible
      tags_page.add_synonym_btn.click

      expect(tags_page.confirm_synonym_btn).to be_visible
      tags_page.confirm_synonym_btn.click

      expect(tags_page.tag_box(tag_2.name)).to be_visible
    end

    it "allows an admin to create a new tag as synonym when tag does not exist" do
      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click
      tags_page.edit_synonyms_btn.click
      tags_page.add_synonyms_select_field.click

      # searched tag doesnt exist but will show option to create tag
      tags_page.search_tags("graphics")
      expect(tags_page.has_search_result?("graphics")).to be_truthy

      tags_page.search_result(1).click
      tags_page.add_synonym_btn.click
      tags_page.confirm_synonym_btn.click

      expect(tags_page.tag_box("graphics")).to be_visible
    end
  end
end
