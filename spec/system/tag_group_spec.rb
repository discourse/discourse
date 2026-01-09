# frozen_string_literal: true

describe "Tag Groups", type: :system do
  fab!(:admin)
  fab!(:tag1) { Fabricate(:tag, name: "cats") }
  fab!(:tag2) { Fabricate(:tag, name: "bats") }
  fab!(:parent_tag) { Fabricate(:tag, name: "parent-tag") }

  let(:tag_groups_page) { PageObjects::Pages::AdminTagGroups.new }

  before do
    SiteSetting.tagging_enabled = true
    sign_in(admin)
  end

  describe "viewing an existing tag group" do
    fab!(:tag_group) do
      Fabricate(:tag_group, name: "Ats", tags: [tag1, tag2]).tap do |tg|
        tg.update!(parent_tag: parent_tag)
        tg.permissions = { 0 => TagGroupPermission.permission_types[:readonly] }
        tg.save!
      end
    end

    it "displays the correct labels and values" do
      tag_groups_page.visit_tag_group(tag_group)

      expect(tag_groups_page).to have_tags_label
      expect(tag_groups_page).to have_parent_tag_label
      expect(tag_groups_page).to have_visible_permission_label
      expect(tag_groups_page).to have_tag_group_in_sidebar("Ats")
      expect(tag_groups_page).to have_tag_in_group("cats")
      expect(tag_groups_page).to have_tag_in_group("bats")
    end
  end

  describe "creating a new tag group" do
    fab!(:existing_tag_group) { Fabricate(:tag_group, name: "Existing Group") }

    it "can create a tag group and see it after refresh" do
      tag_groups_page.visit

      expect(tag_groups_page).to have_tag_group_in_sidebar("Existing Group")

      tag_groups_page.click_new_tag_group
      tag_groups_page.fill_name("New Test Group")

      tag_groups_page.tags_chooser.expand
      tag_groups_page.tags_chooser.search("cats")
      tag_groups_page.tags_chooser.select_row_by_name("cats")
      tag_groups_page.tags_chooser.search("bats")
      tag_groups_page.tags_chooser.select_row_by_name("bats")
      tag_groups_page.tags_chooser.collapse

      tag_groups_page.parent_tag_chooser.expand
      tag_groups_page.parent_tag_chooser.search("parent-tag")
      tag_groups_page.parent_tag_chooser.select_row_by_name("parent-tag")

      tag_groups_page.select_visible_permission
      tag_groups_page.save

      expect(tag_groups_page).to have_tag_group_in_sidebar("New Test Group")

      page.refresh

      expect(tag_groups_page).to have_tag_group_in_sidebar("New Test Group")

      find(".tag-groups-sidebar li", text: "New Test Group").click

      expect(tag_groups_page).to have_tag_in_group("cats")
      expect(tag_groups_page).to have_tag_in_group("bats")
      expect(page).to have_css(".parent-tag-section .tag-chooser", text: "parent-tag")
      expect(find("#visible-permission")).to be_checked
    end
  end
end
