# frozen_string_literal: true

describe "Tag synonyms", type: :system do
  let(:tags_page) { PageObjects::Pages::Tag.new }
  fab!(:tag_1) { Fabricate(:tag, name: "design") }
  fab!(:tag_2) { Fabricate(:tag, name: "art") }
  fab!(:current_user, :admin)

  before { sign_in(current_user) }

  describe "when navigating to a synonym tag" do
    fab!(:target_tag) { Fabricate(:tag, name: "broccoli") }
    fab!(:synonym_tag) { Fabricate(:tag, name: "cauliflower", target_tag:) }
    fab!(:target_tagged_topic) { Fabricate(:topic, tags: [target_tag]) }

    let(:topic_list) { PageObjects::Components::TopicList.new }

    it "redirects to the target tag" do
      tags_page.visit_tag(tag_2)

      tags_page.tags_dropdown.expand
      tags_page.tags_dropdown.search(synonym_tag.name)
      tags_page.tags_dropdown.select_row_by_name(synonym_tag.name)

      expect(topic_list).to have_topic(target_tagged_topic)
      expect(page).to have_current_path("/tag/#{target_tag.name}/#{target_tag.id}")
      expect(tags_page.tags_dropdown).to have_selected_name(target_tag.name)
    end

    it "redirects to the target tag when within a category" do
      category = Fabricate(:category)
      target_tagged_topic.update!(category: category)

      page.visit("/tags/c/#{category.slug}/#{category.id}/#{tag_2.name}")
      expect(page).to have_css(".tag-drop")

      tags_page.tags_dropdown.expand
      tags_page.tags_dropdown.search(synonym_tag.name)
      tags_page.tags_dropdown.select_row_by_name(synonym_tag.name)

      expect(topic_list).to have_topic(target_tagged_topic)
      expect(page).to have_current_path(
        "/tags/c/#{category.slug}/#{category.id}/#{target_tag.name}/#{target_tag.id}",
      )
      expect(tags_page.tags_dropdown).to have_selected_name(target_tag.name)
    end
  end

  describe "when visiting edit tag page" do
    it "allows an admin to add existing tag as a synonym" do
      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click
      tags_page.edit_synonyms_btn.click
      tags_page.select_tag(index: 0)
      tags_page.add_synonym_btn.click

      expect(tags_page.confirm_synonym_btn).to be_visible

      tags_page.confirm_synonym_btn.click

      expect(tags_page.tag_box(tag_2.name)).to be_visible
    end

    it "allows an admin to create a new tag as synonym when tag does not exist" do
      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click
      tags_page.edit_synonyms_btn.click
      # searched tag doesn't exist but will show option to create tag
      tags_page.search_tags("graphics")
      tags_page.select_tag(name: "graphics")
      tags_page.add_synonym_btn.click
      tags_page.confirm_synonym_btn.click

      expect(tags_page.tag_box("graphics")).to be_visible
    end
  end
end
