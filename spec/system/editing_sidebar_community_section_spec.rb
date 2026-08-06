# frozen_string_literal: true

RSpec.describe "Editing Sidebar Community Section" do
  fab!(:admin)
  fab!(:user)

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:sidebar_header_dropdown) { PageObjects::Components::NavigationMenu::HeaderDropdown.new }

  it "should not display the edit section button to non admins" do
    sign_in(user)

    visit("/latest")

    sidebar.click_community_section_more_button

    expect(sidebar).to have_no_customize_community_section_button
  end

  it "Sidebar link DnD oracle lets an admin reorder and reset the Community section" do
    sign_in(admin)

    visit("/latest")

    expect(sidebar.primary_section_icons("community")).to eq(
      %w[layer-group user inbox flag wrench paper-plane ellipsis-vertical],
    )

    modal = sidebar.click_community_section_more_button.click_customize_community_section_button
    modal.fill_link("Topics", "/latest", "paper-plane")
    drag_and_drop(
      source: ".sidebar-section-form-link:has(.draggable[data-link-name='Topics'])",
      # Press the grip, not the row centre: the centre is a text input, and a
      # text-selection drag stalls after dragstart.
      source_position: {
        x: 16,
        y: 20,
      },
      target: ".sidebar-section-form-link:has(.draggable[data-link-name='My messages'])",
      target_position: {
        x: 100,
        y: 55,
      },
    )
    try_until_success do
      expect(
        all(".sidebar-section-form__links-wrapper .draggable").map do |link|
          link["data-link-name"]
        end,
      ).to eq(["My posts", "My messages", "Topics", "Review", "Admin", "Invite"])
    end
    modal.save
    modal.confirm_update

    page.refresh

    try_until_success do
      expect(sidebar.primary_section_links("community")).to eq(
        ["My posts", "My messages", "Topics", "Review", "Admin", "Invite", "More"],
      )
    end

    try_until_success do
      expect(sidebar.primary_section_icons("community")).to eq(
        %w[user inbox paper-plane flag wrench paper-plane ellipsis-vertical],
      )
    end

    modal = sidebar.click_community_section_more_button.click_customize_community_section_button
    modal.reset

    expect(sidebar).to have_section("Community")

    try_until_success do
      expect(sidebar.primary_section_links("community")).to eq(
        ["Topics", "My posts", "My messages", "Review", "Admin", "Invite", "More"],
      )
    end

    try_until_success do
      expect(sidebar.primary_section_icons("community")).to eq(
        %w[layer-group user inbox flag wrench paper-plane ellipsis-vertical],
      )
    end
  end

  it "lets an admin localize manually created Community section links" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "ja"
    user.update!(locale: "ja")

    sign_in(admin)

    visit("/latest")

    modal = sidebar.click_community_section_more_button.click_customize_community_section_button
    modal.add_link
    modal.fill_last_link("Solutions Leaderboard", "/solutions-leaderboard")
    modal.open_translations
    modal.add_language("ja")
    modal.fill_translation("ja", "Solutions Leaderboard", "ソリューションリーダーボード")
    modal.close_translations
    modal.add_link
    modal.fill_last_link("Untranslated Link", "/untranslated-link")
    modal.save
    modal.confirm_update

    sign_in(user)

    visit("/latest")

    expect(sidebar).to have_community_section_link("ソリューションリーダーボード", href: "/solutions-leaderboard")
    expect(sidebar).to have_community_section_link("Untranslated Link", href: "/untranslated-link")
  end

  it "allows admin to edit community section when no secondary section links" do
    SidebarSection
      .where(title: "Community")
      .first
      .sidebar_section_links
      .where.not(position: 0)
      .destroy_all

    sign_in(admin)

    visit("/latest")

    modal = sidebar.click_customize_community_section_button

    expect(modal).to be_visible
  end

  it "should allow admins to open modal to edit the section when `navigation_menu` site setting is `header dropdown`" do
    SiteSetting.navigation_menu = "header dropdown"

    sign_in(admin)

    visit("/latest")

    sidebar_header_dropdown.open
    expect(sidebar_header_dropdown).to have_dropdown_visible
    modal = sidebar_header_dropdown.click_customize_community_section_button

    expect(modal).to be_visible
  end
end
