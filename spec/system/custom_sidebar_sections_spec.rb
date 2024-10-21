# frozen_string_literal: true

describe "Custom sidebar sections", type: :system do
  fab!(:user)
  fab!(:admin)
  let(:section_modal) { PageObjects::Modals::SidebarSectionForm.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { user.user_option.update!(external_links_in_new_tab: true) }

  shared_examples "creating custom sections" do |relative_root_url|
    it "allows the user to create custom section" do
      visit("#{relative_root_url}/latest")

      expect(sidebar).to have_no_add_section_button

      sign_in user
      visit("#{relative_root_url}/latest")
      sidebar.click_add_section_button

      expect(section_modal).to be_visible
      expect(section_modal).to have_disabled_save
      expect(sidebar.custom_section_modal_title).to have_content("Add custom section")

      section_modal.fill_name("My section")

      section_modal.fill_link("Sidebar Tags", "/tags")
      expect(section_modal).to have_enabled_save

      section_modal.save

      expect(sidebar).to have_section("My section")
      expect(sidebar).to have_section_link("Sidebar Tags")
    end
  end

  include_examples "creating custom sections"

  context "when subfolder install" do
    before { set_subfolder "/community" }

    include_examples "creating custom sections", "/community"
  end

  it "allows the user to create custom section with /my link" do
    sign_in user
    visit("/latest")

    sidebar.click_add_section_button
    section_modal.fill_name("My section")
    section_modal.fill_link("My preferences", "/my/preferences")
    section_modal.save

    expect(sidebar).to have_section("My section")
    expect(sidebar).to have_section_link("My preferences", target: "_self")
  end

  it "allows the user to create custom section with `/` path" do
    SiteSetting.top_menu = "read|posted|latest"

    sign_in user
    visit("/latest")

    sidebar.click_add_section_button
    section_modal.fill_name("My section")
    section_modal.fill_link("Home", "/")
    section_modal.save

    expect(sidebar).to have_section("My section")
    expect(sidebar).to have_section_link("Home", href: "/")

    sidebar.click_section_link("Home")
    expect(page).to have_css("#navigation-bar .active a[href='/read']")
  end

  it "allows the user to create custom section with /pub link" do
    sign_in user
    visit("/latest")

    sidebar.click_add_section_button
    section_modal.fill_name("My section")
    section_modal.fill_link("Published Page", "/pub/test")
    section_modal.save

    expect(sidebar).to have_section("My section")
    expect(sidebar).to have_section_link("Published Page", target: "_self")
  end

  it "allows the user to create custom section with external link" do
    sign_in user
    visit("/latest")
    sidebar.click_add_section_button

    expect(section_modal).to be_visible
    expect(section_modal).to have_disabled_save
    expect(sidebar.custom_section_modal_title).to have_content("Add custom section")

    section_modal.fill_name("My section")

    section_modal.fill_link("Discourse Homepage", "https://discourse.org")
    expect(section_modal).to have_enabled_save

    section_modal.save

    expect(sidebar).to have_section("My section")
    expect(sidebar).to have_section_link(
      "Discourse Homepage",
      href: "https://discourse.org",
      target: "_blank",
    )
  end

  it "allows the user to create custom section with anchor" do
    sign_in user
    visit("/latest")
    sidebar.click_add_section_button

    expect(section_modal).to be_visible
    expect(section_modal).to have_disabled_save
    expect(sidebar.custom_section_modal_title).to have_content("Add custom section")

    section_modal.fill_name("My section")
    section_modal.fill_link("Faq", "/faq#anchor")
    section_modal.save

    expect(sidebar).to have_section("My section")
    expect(sidebar).to have_section_link("Faq", target: "_self", href: "/faq#anchor")
  end

  it "allows the user to create custom section with query param" do
    sign_in user
    visit("/latest")
    sidebar.click_add_section_button

    expect(section_modal).to be_visible
    expect(section_modal).to have_disabled_save
    expect(sidebar.custom_section_modal_title).to have_content("Add custom section")

    section_modal.fill_name("My section")
    section_modal.fill_link("Faq", "/faq?a=b")
    section_modal.save

    expect(sidebar).to have_section("My section")
    expect(sidebar).to have_section_link("Faq", target: "_self", href: "/faq?a=b")
  end

  it "allows the user to create custom section with anchor link" do
    sign_in user
    visit("/latest")
    sidebar.click_add_section_button

    expect(section_modal).to be_visible
    expect(section_modal).to have_disabled_save
    expect(sidebar.custom_section_modal_title).to have_content("Add custom section")

    section_modal.fill_name("My section")
    section_modal.fill_link("Faq", "/faq#someheading")
    section_modal.save

    expect(sidebar).to have_section("My section")
    expect(sidebar).to have_section_link("Faq", target: "_self", href: "/faq#someheading")
  end

  it "accessibility - when new row is added in custom section, first new input is focused" do
    sign_in user
    visit("/latest")

    sidebar.click_add_section_button
    sidebar.click_add_link_button

    is_focused =
      page.evaluate_script("document.activeElement.classList.contains('multi-select-header')")

    expect(is_focused).to be true
  end

  it "accessibility - when customization modal is closed, trigger is refocused" do
    sign_in user
    visit("/latest")

    sidebar.click_add_section_button

    find(".modal-close").click

    is_focused = page.evaluate_script("document.activeElement.classList.contains('add-section')")

    expect(is_focused).to be true
  end

  it "allows the user to edit custom section" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    sidebar_url_2 = Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    sign_in user
    visit("/latest")

    sidebar.edit_custom_section("My section")
    expect(find("#discourse-modal-title")).to have_content("Edit custom section")

    section_modal.fill_name("Edited section")
    section_modal.fill_link("Edited Tags", "/tags")
    section_modal.remove_last_link

    section_modal.save

    expect(sidebar).to have_section("Edited section")
    expect(sidebar).to have_section_link("Edited Tags")

    expect(sidebar).to have_no_section_link("Sidebar Categories")
  end

  it "allows the user to reorder links in custom section" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)

    sidebar_url_1 =
      Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags").tap do |sidebar_url|
        Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
      end

    sidebar_url_2 =
      Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories").tap do |sidebar_url|
        Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
      end

    sidebar_url_3 =
      Fabricate(:sidebar_url, name: "Sidebar Latest", value: "/latest").tap do |sidebar_url|
        Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
      end

    sign_in user

    visit("/latest")

    expect(sidebar.primary_section_links("my-section")).to eq(
      ["Sidebar Tags", "Sidebar Categories", "Sidebar Latest"],
    )

    sidebar.edit_custom_section("My section")

    tags_link = find(".draggable[data-link-name='Sidebar Tags']")
    latest_link = find(".draggable[data-link-name='Sidebar Latest']")
    tags_link.drag_to(latest_link, html5: true, delay: 0.4)
    section_modal.save
    expect(section_modal).to be_closed

    expect(sidebar.primary_section_links("my-section")).to eq(
      ["Sidebar Categories", "Sidebar Tags", "Sidebar Latest"],
    )
  end

  it "does not allow to drag on mobile", mobile: true do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)

    Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags").tap do |sidebar_url|
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
    end

    Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories").tap do |sidebar_url|
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
    end

    sign_in user

    visit("/latest")

    sidebar.open_on_mobile
    sidebar.edit_custom_section("My section")

    expect(page).not_to have_css(".sidebar-section-form-link .draggable")
  end

  it "does not allow the user to edit public section" do
    sidebar_section = Fabricate(:sidebar_section, title: "Public section", public: true)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    sidebar_url_2 = Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    sign_in user
    visit("/latest")

    expect(sidebar).to have_section("Public section")

    find(".sidebar-section[data-section-name='public-section']").hover

    expect(page).not_to have_css(
      ".sidebar-section[data-section-name='public-section'] button.sidebar-section-header-button",
    )

    expect(page).not_to have_css(
      ".sidebar-section[data-section-name='public-section'] .d-icon-globe",
    )
  end

  it "allows the user to delete custom section" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)

    sign_in user
    visit("/latest")

    sidebar.edit_custom_section("My section")

    section_modal.delete
    expect(section_modal).to have_text("Are you sure you want to delete this section?")
    section_modal.confirm_delete

    expect(sidebar).to have_no_section("My section")
  end

  it "allows admin to create, edit and delete public section" do
    sign_in admin
    visit("/latest")
    sidebar.click_add_section_button

    section_modal.fill_name("Public section")
    section_modal.fill_link("Sidebar Tags", "/tags")
    section_modal.mark_as_public
    section_modal.save

    expect(sidebar).to have_section("Public section")
    expect(sidebar).to have_section_link("Sidebar Tags")
    expect(page).to have_css(".sidebar-section[data-section-name='public-section'] .d-icon-globe")

    sidebar.edit_custom_section("Public section")
    section_modal.fill_name("Edited public section")
    section_modal.save

    expect(section_modal).to have_text(
      "Changes will be visible to everyone on this site. Are you sure?",
    )

    section_modal.confirm_update

    expect(sidebar).to have_section("Edited public section")

    sidebar.edit_custom_section("Edited public section")
    section_modal.delete
    expect(section_modal).to have_text(
      "This section is visible to everyone, are you sure you want to delete it?",
    )
    section_modal.confirm_delete

    expect(sidebar).to have_no_section("Edited public section")
  end

  it "displays warning when public section is marked as private" do
    sign_in admin
    visit("/latest")
    sidebar.click_add_section_button

    section_modal.fill_name("Public section")
    section_modal.fill_link("Sidebar Tags", "/tags")
    section_modal.mark_as_public
    section_modal.save

    sidebar.edit_custom_section("Public section")
    section_modal.fill_name("Edited public section")
    section_modal.mark_as_public
    section_modal.save

    expect(section_modal).to have_text(
      "This section is visible to everyone. After the update, it will be visible only to you. Are you sure?",
    )

    section_modal.confirm_update

    expect(sidebar).to have_section("Edited public section")
    expect(page).not_to have_css(
      ".sidebar-section[data-section-name='edited-public-section'] .d-icon-globe",
    )
  end

  it "shows anonymous public sections" do
    sidebar_section = Fabricate(:sidebar_section, title: "Public section", public: true)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    sidebar_url_2 = Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    visit("/latest")
    expect(sidebar).to have_section("Public section")
    expect(sidebar).to have_section_link("Sidebar Tags")
    expect(sidebar).to have_section_link("Sidebar Categories")
  end

  it "validates custom section fields" do
    sign_in user
    visit("/latest")
    sidebar.click_add_section_button

    section_modal.fill_name("A" * (SidebarSection::MAX_TITLE_LENGTH + 1))
    section_modal.fill_link("B" * (SidebarUrl::MAX_NAME_LENGTH + 1), "https:")

    expect(page.find(".title.warning")).to have_content("Title must be shorter than 30 characters")
    expect(page.find(".name.warning")).to have_content("Name must be shorter than 80 characters")
    expect(page.find(".value.warning")).to have_content("Format is invalid")

    section_modal.fill_name("")
    section_modal.fill_link("", "")
    expect(page.find(".title.warning")).to have_content("Title cannot be blank")
    expect(page.find(".name.warning")).to have_content("Name cannot be blank")
    expect(page.find(".value.warning")).to have_content("Link cannot be blank")

    expect(section_modal).to have_disabled_save
  end

  it "allows the user to expand/collapse section containing unicode titles separately" do
    sidebar_section1 = Fabricate(:sidebar_section, title: "談話", user: user)
    Fabricate(:sidebar_url, name: "Sidebar Latest", value: "/latest").tap do |sidebar_url|
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section1, linkable: sidebar_url)
    end

    sidebar_section2 = Fabricate(:sidebar_section, title: "趣", user: user)
    Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories").tap do |sidebar_url|
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section2, linkable: sidebar_url)
    end

    sign_in user

    visit("/latest")

    expect(sidebar).to have_section_expanded("談話")
    expect(sidebar).to have_section_expanded("趣")

    sidebar.click_section_header("談話")
    expect(sidebar).to have_section_collapsed("談話")
    expect(sidebar).to have_section_expanded("趣")

    sidebar.click_section_header("趣")
    expect(sidebar).to have_section_collapsed("談話")
    expect(sidebar).to have_section_collapsed("趣")

    sidebar.click_section_header("談話")
    expect(sidebar).to have_section_expanded("談話")
    expect(sidebar).to have_section_collapsed("趣")

    sidebar.click_section_header("趣")
    expect(sidebar).to have_section_expanded("談話")
    expect(sidebar).to have_section_expanded("趣")
  end
end
