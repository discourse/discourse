# frozen_string_literal: true

describe "Tag Edit", type: :system do
  let(:tags_page) { PageObjects::Pages::Tag.new }
  fab!(:tag_1) { Fabricate(:tag, name: "design") }
  fab!(:current_user) { Fabricate(:admin) }

  before { sign_in(current_user) }

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
