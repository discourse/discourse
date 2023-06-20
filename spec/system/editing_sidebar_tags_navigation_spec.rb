# frozen_string_literal: true

RSpec.describe "Editing sidebar tags navigation", type: :system do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group).tap { |g| g.add(user) } }
  fab!(:tag) { Fabricate(:tag, name: "tag", public_topic_count: 1, staff_topic_count: 1) }
  fab!(:tag2) { Fabricate(:tag, name: "tag2", public_topic_count: 2, staff_topic_count: 2) }
  fab!(:tag3) { Fabricate(:tag, name: "tag3", public_topic_count: 3, staff_topic_count: 3) }

  let(:sidebar) { PageObjects::Components::Sidebar.new }

  before do
    SiteSetting.new_edit_sidebar_categories_tags_interface_groups = group.name
    sign_in(user)
  end

  it "allows a user to edit the sidebar categories navigation" do
    visit "/latest"

    expect(sidebar).to have_tags_section
    expect(sidebar).to have_no_section_link(tag.name)
    expect(sidebar).to have_no_section_link(tag2.name)
    expect(sidebar).to have_no_section_link(tag3.name)

    modal = sidebar.click_edit_tags_button

    expect(modal).to have_right_title(I18n.t("js.sidebar.tags_form_modal.title"))
    expect(modal).to have_tag_checkboxes([tag, tag2, tag3])

    modal.toggle_tag_checkbox(tag).toggle_tag_checkbox(tag2).save

    expect(modal).to be_closed
    expect(sidebar).to have_section_link(tag.name)
    expect(sidebar).to have_section_link(tag2.name)
    expect(sidebar).to have_no_section_link(tag3.name)

    visit "/latest"

    expect(sidebar).to have_section_link(tag.name)
    expect(sidebar).to have_section_link(tag2.name)
    expect(sidebar).to have_no_section_link(tag3.name)

    modal = sidebar.click_edit_tags_button
    modal.toggle_tag_checkbox(tag2).save

    expect(modal).to be_closed

    expect(sidebar).to have_section_link(tag.name)
    expect(sidebar).to have_no_section_link(tag2.name)
    expect(sidebar).to have_no_section_link(tag3.name)
  end
end
