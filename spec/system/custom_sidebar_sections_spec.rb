# frozen_string_literal: true

describe "Custom sidebar sections", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  let(:section_modal) { PageObjects::Modals::SidebarSectionForm.new }
  let(:sidebar) { PageObjects::Components::Sidebar.new }

  before do
    ### TODO remove when enable_custom_sidebar_sections SiteSetting is removed
    group = Fabricate(:group)
    Fabricate(:group_user, group: group, user: user)
    SiteSetting.enable_custom_sidebar_sections = group.id.to_s
    sign_in user
  end

  it "allows the user to create custom section" do
    visit("/latest")
    sidebar.open_new_custom_section

    expect(section_modal).to be_visible
    expect(section_modal).to have_disabled_save
    expect(find("#discourse-modal-title")).to have_content("Add custom section")

    section_modal.fill_name("My section")

    section_modal.fill_link("Sidebar Tags", "/tags")
    expect(section_modal).to have_enabled_save

    section_modal.save

    expect(page).to have_button("My section")
    expect(page).to have_link("Sidebar Tags")
  end

  it "allows the user to edit custom section" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    sidebar_url_2 = Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    visit("/latest")

    sidebar.edit_custom_section("My section")
    expect(find("#discourse-modal-title")).to have_content("Edit custom section")

    section_modal.fill_name("Edited section")
    section_modal.fill_link("Edited Tags", "/tags")
    section_modal.remove_last_link

    section_modal.save

    expect(page).to have_button("Edited section")
    expect(page).to have_link("Edited Tags")
    expect(page).not_to have_link("Sidebar Categories")
  end

  it "allows the user to delete custom section" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)

    visit("/latest")

    sidebar.edit_custom_section("My section")

    section_modal.delete
    section_modal.confirm_delete

    expect(page).not_to have_button("My section")
  end
end
