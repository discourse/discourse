# frozen_string_literal: true

describe "Tag Settings" do
  let(:tags_page) { PageObjects::Pages::Tag.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:tag_settings_page) { PageObjects::Pages::TagSettings.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  fab!(:tag_1) { Fabricate(:tag, name: "design", description: "tomtom is design") }
  fab!(:tag_2) { Fabricate(:tag, name: "cat") }
  fab!(:synonym) { Fabricate(:tag, name: "design-synonym", target_tag: tag_1) }
  fab!(:admin)
  fab!(:trust_level_4)
  fab!(:user)

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.edit_tags_allowed_groups = "1|2|14"
  end

  context "when using the tag settings page" do
    it "loads the tag edit page for tags with empty slugs" do
      tag_1.update_column(:slug, "")
      sign_in(admin)

      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click

      expect(tag_settings_page).to have_tag_settings_page
      expect(page).to have_current_path("/tag/#{tag_1.id}-tag/#{tag_1.id}/edit/general")
      expect(tag_settings_page).to have_name_value(tag_1.name)
      expect(tag_settings_page).to have_slug_value("#{tag_1.id}-tag")
    end

    it "allows privileged users to access the new tag settings page" do
      sign_in(admin)

      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click
      expect(page).to have_current_path("/tag/#{tag_1.slug}/#{tag_1.id}/edit/general")

      sign_in(trust_level_4)
      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click
      expect(page).to have_current_path("/tag/#{tag_1.slug}/#{tag_1.id}/edit/general")

      sign_in(user)
      tags_page.visit_tag(tag_1)

      expect(tags_page).to have_no_tag_info_btn
      visit("/tag/#{tag_1.slug}/#{tag_1.id}/edit/general")
      expect(page).to have_current_path("/tag/#{tag_1.slug}/#{tag_1.id}")
    end

    it "allows privileged users to edit tag, admin to delete tag" do
      sign_in(trust_level_4)
      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click

      expect(page).to have_no_css(".d-page-header__actions .btn-danger")
      expect(tag_settings_page).to have_name_value(tag_1.name)
      expect(tag_settings_page).to have_slug_value(tag_1.slug)
      expect(tag_settings_page).to have_description_value(tag_1.description)
      expect(tag_settings_page).to have_synonym(synonym.name)

      tag_settings_page.fill_name("updated-name")
      tag_settings_page.fill_slug("custom-slug")
      tag_settings_page.fill_description("new description")
      tag_settings_page.remove_synonym(synonym.name)
      expect(tag_settings_page).to have_no_synonyms
      tag_settings_page.click_save

      expect(toasts).to have_success(I18n.t("js.tagging.settings.saved"))

      expect(page).to have_current_path("/tag/custom-slug/#{tag_1.id}/edit/general")
      expect(tag_settings_page).to have_name_value("updated-name")
      expect(tag_settings_page).to have_slug_value("custom-slug")
      expect(tag_settings_page).to have_description_value("new description")
      expect(tag_settings_page).to have_no_synonyms

      sign_in(admin)
      tags_page.visit_tag(tag_2)
      tags_page.tag_info_btn.click
      expect(page).to have_css(".d-page-header__actions .btn-danger")
      tag_settings_page.click_delete
      dialog.click_danger
      expect(page).to have_current_path("/tags")

      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click
      tag_settings_page.click_back
      expect(page).to have_current_path("/tag/custom-slug/#{tag_1.id}")
    end

    it "allows adding an existing tag as synonym" do
      sign_in(admin)
      tag_settings_page.visit(tag_1)
      tag_settings_page.add_synonym(tag_2.name)
      tag_settings_page.click_save

      dialog.click_yes

      expect(toasts).to have_success(I18n.t("js.tagging.settings.saved"))
      expect(tag_settings_page).to have_synonym(tag_2.name)
    end
  end

  context "when navigating to a synonym tag" do
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
end
