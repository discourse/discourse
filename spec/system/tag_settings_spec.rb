# frozen_string_literal: true

describe "Tag Settings", type: :system do
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

  context "when experimental_tag_settings_page is enabled" do
    before { SiteSetting.experimental_tag_settings_page = true }

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

      expect(tags_page).to have_tag_info_btn
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
  end

  context "when experimental_tag_settings_page is disabled" do
    before { SiteSetting.experimental_tag_settings_page = false }

    context "when signed in as admin" do
      before { sign_in(admin) }

      it "allows the admin to edit a tag name and description, and delete the tag" do
        tags_page.visit_tag(tag_1)
        tags_page.tag_info_btn.click
        tags_page.open_edit_tag

        tags_page.fill_tag_name("ux")
        tags_page.fill_tag_description("new description")
        tags_page.save_edit
        expect(tags_page.tag_info).to have_content("ux")
        expect(tags_page.tag_info).to have_content("new description")

        tags_page.delete_tag
        expect(dialog).to be_open
        dialog.click_danger
        expect(tags_page).to have_no_tag("design")
      end

      it "does not error when editing a tag name to something then reverting back to the original name" do
        tags_page.visit_tag(tag_1)
        tags_page.tag_info_btn.click
        tags_page.open_edit_tag
        tags_page.fill_tag_name("ux")
        tags_page.save_edit
        expect(tags_page.tag_info).to have_content("ux")
        tags_page.open_edit_tag
        tags_page.fill_tag_name("design")
        tags_page.save_edit
        expect(tags_page.tag_info).to have_content("design")
      end

      it "allows adding tags as synonyms" do
        tags_page.visit_tag(tag_1)
        tags_page.tag_info_btn.click
        tags_page.edit_synonyms_btn.click

        tags_page.select_tag(index: 0)
        tags_page.search_tags("kittehs")
        tags_page.select_tag(value: "kittehs")
        tags_page.add_synonym_btn.click

        expect(tags_page.confirm_synonym_btn).to be_visible
        tags_page.confirm_synonym_btn.click

        expect(tags_page.tag_box(tag_2.name)).to be_visible
        expect(tags_page.tag_box("kittehs")).to be_visible
      end
    end

    context "when signed in as a user allowed to edit tags" do
      before { sign_in(trust_level_4) }

      it "allows the user to edit a tag name and description, but cannot delete the tag" do
        tags_page.visit_tag(tag_1)
        tags_page.tag_info_btn.click
        tags_page.open_edit_tag

        tags_page.fill_tag_name("ux")
        tags_page.fill_tag_description("new description")
        tags_page.save_edit
        expect(tags_page.tag_info).to have_content("ux")
        expect(tags_page.tag_info).to have_content("new description")

        expect(tags_page.tag_info).to have_no_css(".delete-tag")
      end
    end

    context "when signed in as a regular user" do
      before { sign_in(user) }

      it "does not allow the user to edit or delete the tag" do
        tags_page.visit_tag(tag_1)
        tags_page.tag_info_btn.click
        expect(tags_page.tag_info).to have_no_css(".edit-tag")
        expect(tags_page.tag_info).to have_no_css(".delete-tag")
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
end
