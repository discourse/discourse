# frozen_string_literal: true

describe "Tag Edit", type: :system do
  let(:tags_page) { PageObjects::Pages::Tag.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  fab!(:tag_1) { Fabricate(:tag, name: "design") }
  fab!(:user)
  fab!(:admin)
  fab!(:trust_level_4)

  before { SiteSetting.edit_tags_allowed_groups = "1|2|14" }

  context "when signed in as admin" do
    before { sign_in(admin) }

    it "allows the admin to edit a tag name and description" do
      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click
      tags_page.open_edit_tag
      tags_page.fill_tag_name("ux")
      tags_page.fill_tag_description("new description")
      tags_page.save_edit
      expect(tags_page.tag_info).to have_content("ux")
      expect(tags_page.tag_info).to have_content("new description")
    end

    it "allows the admin to delete the tag" do
      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click
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
  end

  context "when signed in as a user allowed to edit tags" do
    before { sign_in(trust_level_4) }

    it "allows the user to edit a tag name and description" do
      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click
      tags_page.open_edit_tag
      tags_page.fill_tag_name("ux")
      tags_page.fill_tag_description("new description")
      tags_page.save_edit
      expect(tags_page.tag_info).to have_content("ux")
      expect(tags_page.tag_info).to have_content("new description")
    end

    it "does not allow the user to delete the tag" do
      tags_page.visit_tag(tag_1)
      tags_page.tag_info_btn.click
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
end
