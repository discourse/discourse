# frozen_string_literal: true

describe "Custom sidebar sections", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  let(:section_modal) { PageObjects::Modals::SidebarSectionForm.new }
  let(:sidebar) { PageObjects::Components::Sidebar.new }

  before do
    ### TODO remove when enable_custom_sidebar_sections SiteSetting is removed
    group = Fabricate(:group)
    Fabricate(:group_user, group: group, user: user)
    Fabricate(:group_user, group: group, user: admin)
    SiteSetting.enable_custom_sidebar_sections = group.id.to_s
    sign_in user
  end

  it "allows the user to create custom section" do
    visit("/latest")
    sidebar.open_new_custom_section

    expect(section_modal).to be_visible
    expect(section_modal).to have_disabled_save
    expect(sidebar.custom_section_modal_title).to have_content("Add custom section")

    section_modal.fill_name("My section")

    section_modal.fill_link("Sidebar Tags", "/tags")
    expect(section_modal).to have_enabled_save

    section_modal.save

    expect(page).to have_button("My section")
    expect(sidebar).to have_link("Sidebar Tags")
  end

  it "allows the user to create custom section with external link" do
    visit("/latest")
    sidebar.open_new_custom_section

    expect(section_modal).to be_visible
    expect(section_modal).to have_disabled_save
    expect(sidebar.custom_section_modal_title).to have_content("Add custom section")

    section_modal.fill_name("My section")

    section_modal.fill_link("Discourse Homepage", "htt")
    expect(section_modal).to have_disabled_save

    section_modal.fill_link("Discourse Homepage", "https://discourse.org")
    expect(section_modal).to have_enabled_save

    section_modal.save

    expect(page).to have_button("My section")
    expect(sidebar).to have_link("Discourse Homepage", href: "https://discourse.org")
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
    expect(sidebar).to have_link("Edited Tag")

    expect(page).not_to have_link("Sidebar Categories")
  end

  it "allows the user to reorder links in custom section" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    sidebar_url_2 = Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    visit("/latest")
    within(".sidebar-custom-sections .sidebar-section-link-wrapper:nth-child(1)") do
      expect(page).to have_css(".sidebar-section-link-sidebar-tags")
    end
    within(".sidebar-custom-sections .sidebar-section-link-wrapper:nth-child(2)") do
      expect(page).to have_css(".sidebar-section-link-sidebar-categories")
    end

    tags_link = find(".sidebar-section-link-sidebar-tags")
    categories_link = find(".sidebar-section-link-sidebar-categories")
    tags_link.drag_to(categories_link)

    within(".sidebar-custom-sections .sidebar-section-link-wrapper:nth-child(1)") do
      expect(page).to have_css(".sidebar-section-link-sidebar-categories")
    end
    within(".sidebar-custom-sections .sidebar-section-link-wrapper:nth-child(2)") do
      expect(page).to have_css(".sidebar-section-link-sidebar-tags")
    end
  end

  it "does not allow the user to edit public section" do
    sidebar_section = Fabricate(:sidebar_section, title: "Public section", user: user, public: true)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    sidebar_url_2 = Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    visit("/latest")

    expect(page).to have_button("Public section")
    find(".sidebar-section-public-section").hover
    expect(page).not_to have_css(
      ".sidebar-section-public-section button.sidebar-section-header-button",
    )
    expect(page).not_to have_css(".sidebar-section-public-section .d-icon-globe")
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

  it "allows admin to create, edit and delete public section" do
    sign_in admin
    visit("/latest")
    sidebar.open_new_custom_section

    section_modal.fill_name("Public section")
    section_modal.fill_link("Sidebar Tags", "/tags")
    section_modal.mark_as_public
    section_modal.save

    expect(page).to have_button("Public section")
    expect(sidebar).to have_link("Sidebar Tags")
    expect(page).to have_css(".sidebar-section-public-section .d-icon-globe")

    sidebar.edit_custom_section("Public section")
    section_modal.fill_name("Edited public section")
    section_modal.save

    expect(page).to have_button("Edited public section")

    sidebar.edit_custom_section("Edited public section")
    section_modal.delete
    section_modal.confirm_delete

    expect(page).not_to have_button("Edited public section")
  end
end
