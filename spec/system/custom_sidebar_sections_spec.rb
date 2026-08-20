# frozen_string_literal: true

describe "Custom sidebar sections" do
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
      expect(section_modal).to have_section_links_label
      expect(sidebar.custom_section_modal_title).to have_content("Add custom section")

      section_modal.fill_name("My section")
      section_modal.fill_link("Sidebar Tags", "/tags")

      expect(section_modal).to have_enabled_save

      section_modal.save

      expect(section_modal).to be_closed
      expect(sidebar).to have_section("My section")
      expect(sidebar).to have_section_link("Sidebar Tags")
    end
  end

  include_examples "creating custom sections"

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

  it "prioritizes exact url matches over ember routes" do
    sidebar_section = SidebarSection.find_by(section_type: "community")
    sidebar_url = Fabricate(:sidebar_url, name: "Topics", value: "/latest")
    sidebar_url_2 =
      Fabricate(:sidebar_url, name: "Sorted latest", value: "/latest?ascending=true&order=posts")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    sign_in user

    visit("/latest?ascending=true&order=posts")
    expect(sidebar).to have_exact_url_match_link("Sorted latest")
    expect(sidebar).to have_no_active_links
    expect(sidebar).to have_no_exact_url_match_link("everything")

    visit("/latest")
    expect(sidebar).to have_active_link("everything")
    expect(sidebar).to have_no_exact_url_match_link("Sorted latest")
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

  it "allows typing in the icon picker filter input" do
    sign_in user
    visit("/latest")
    sidebar.click_add_section_button

    picker = section_modal.first_link_icon_picker
    picker.expand.type_filter("globe")

    expect(picker.filter_input.value).to eq("globe")
    expect(picker).to have_icon("globe")
  end

  it "accessibility - when new row is added in custom section, first new input is focused" do
    sign_in user
    visit("/latest")

    sidebar.click_add_section_button
    sidebar.click_add_link_button

    is_focused =
      page.evaluate_script(
        "document.activeElement.classList.contains('d-icon-grid-picker-trigger')",
      )

    expect(is_focused).to be true
  end

  it "accessibility - when customization modal is closed, trigger is refocused" do
    sign_in user
    visit("/latest")

    sidebar.click_add_section_button
    section_modal.close

    expect(section_modal).to be_closed

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

  it "lets the user select text in a link's fields" do
    # The row is a drag source, and a `draggable` element turns a press-drag into
    # a drag rather than a selection. These rows are a form: the name and URL are
    # text inputs whose contents a user edits and copies, so only the grip may be
    # draggable.
    #
    # A selection inside a form control does not appear in `window.getSelection`,
    # so this reads the input's own selection range.
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)

    Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags").tap do |sidebar_url|
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
    end

    sign_in user
    visit("/latest")
    sidebar.edit_custom_section("My section")

    url_field = ".sidebar-section-form-link input[name='link-url']"
    # Leftwards and well past the field's edge: the press lands at its centre,
    # which for a short value is beyond the end of the text, so a short sweep
    # crosses no characters and would fail whether or not selection works. A
    # drag running off the edge still selects back to the start.
    drag_with_pointer(from: url_field, by: { x: -400 })

    expect(
      page.evaluate_script(
        "(() => { const i = document.querySelector(\"#{url_field}\"); " \
          "return i.selectionEnd - i.selectionStart; })()",
      ),
    ).to be > 0
  end

  it "lets the user reorder links in a custom section" do
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

    drag_and_drop(
      source: ".sidebar-section-form-link:has(.draggable[data-link-name='Sidebar Tags'])",
      # Press the grip, not the row centre: the centre is a text input, and a
      # text-selection drag stalls after dragstart.
      source_position: {
        x: 16,
        y: 20,
      },
      target: ".sidebar-section-form-link:has(.draggable[data-link-name='Sidebar Categories'])",
      target_position: {
        x: 100,
        y: 55,
      },
    )
    try_until_success do
      expect(section_modal.link_names).to eq(
        ["Sidebar Categories", "Sidebar Tags", "Sidebar Latest"],
      )
    end
    section_modal.save
    expect(section_modal).to be_closed

    try_until_success do
      expect(sidebar.primary_section_links("my-section")).to eq(
        ["Sidebar Categories", "Sidebar Tags", "Sidebar Latest"],
      )
    end
  end

  it "lets the user reorder links with the keyboard" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)

    ["Sidebar Tags", "Sidebar Categories", "Sidebar Latest"].each do |name|
      Fabricate(:sidebar_url, name: name, value: "/#{name.parameterize}").tap do |sidebar_url|
        Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
      end
    end

    sign_in user

    visit("/latest")

    sidebar.edit_custom_section("My section")

    # Asserted before the move: without it, a run where the order already matched
    # would pass whether or not the arrow did anything.
    expect(section_modal.link_names).to eq(["Sidebar Tags", "Sidebar Categories", "Sidebar Latest"])

    section_modal.move_link_down("Sidebar Tags")

    try_until_success do
      expect(section_modal.link_names).to eq(
        ["Sidebar Categories", "Sidebar Tags", "Sidebar Latest"],
      )
    end

    # Focus is where the arrows live or die: the row moves in the DOM under the
    # pressed button, and a lost focus makes a second press impossible.
    expect(section_modal.focused_label).to eq("Move Sidebar Tags down")

    # So the second press goes through whatever holds focus, not through another
    # lookup by name, which would pass even if focus had been dropped.
    section_modal.press_focused_link_arrow

    try_until_success do
      expect(section_modal.link_names).to eq(
        ["Sidebar Categories", "Sidebar Latest", "Sidebar Tags"],
      )
    end

    section_modal.save
    expect(section_modal).to be_closed

    try_until_success do
      expect(sidebar.primary_section_links("my-section")).to eq(
        ["Sidebar Categories", "Sidebar Latest", "Sidebar Tags"],
      )
    end
  end

  it "offers both the drag handle and the arrows on mobile", mobile: true do
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

    # The handle renders on every viewport now that the drag begins on the grip
    # rather than anywhere on the row, so a press meant to scroll still scrolls.
    expect(page).to have_css(".sidebar-section-form-link .draggable")

    # Neither path substitutes for the other: the arrows are the only route
    # without a pointer, and the drag is the only route without a keyboard.
    section_modal.move_link_down("Sidebar Tags")

    try_until_success do
      expect(section_modal.link_names).to eq(["Sidebar Categories", "Sidebar Tags"])
    end
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

  it "shows localized public custom sections" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "ja"
    user.update!(locale: "ja")
    sidebar_section =
      Fabricate(:sidebar_section, title: "Public section", public: true, locale: "en")
    Fabricate(:sidebar_section_localization, sidebar_section:, locale: "ja", title: "公開セクション")
    sidebar_url = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags", locale: "en")
    Fabricate(:sidebar_url_localization, sidebar_url:, locale: "ja", name: "タグ")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)

    sign_in user
    visit("/latest")

    expect(page).to have_css(".sidebar-section-header", text: "公開セクション")
    expect(page).to have_css(".sidebar-section-link", text: "タグ")
  end

  it "loads source labels when editing localized public custom sections" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "ja"
    admin.update!(locale: "ja")
    sidebar_section =
      Fabricate(:sidebar_section, title: "Public section", public: true, locale: "en")
    Fabricate(:sidebar_section_localization, sidebar_section:, locale: "ja", title: "公開セクション")
    sidebar_url = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags", locale: "en")
    Fabricate(:sidebar_url_localization, sidebar_url:, locale: "ja", name: "タグ")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)

    sign_in admin
    visit("/latest")

    expect(page).to have_css(".sidebar-section-header", text: "公開セクション")
    expect(page).to have_css(".sidebar-section-link", text: "タグ")

    sidebar.edit_custom_section("Public section")

    expect(section_modal).to have_section_name("Public section")
    expect(section_modal).to have_first_link_name("Sidebar Tags")
  end

  it "shows translation controls only when a section is visible to everyone" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "ja|zh_CN"
    sidebar_section =
      Fabricate(:sidebar_section, title: "Public section", public: true, locale: "en")
    Fabricate(:sidebar_section_localization, sidebar_section:, locale: "ja", title: "公開セクション")
    sidebar_url = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags", locale: "en")
    Fabricate(:sidebar_url_localization, sidebar_url:, locale: "ja", name: "タグ")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Public section")

    expect(section_modal).to have_localization_controls

    section_modal.mark_as_public

    expect(section_modal).to have_no_localization_controls
  end

  it "does not show translation controls for the built-in community section" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "ja"

    sign_in admin
    visit("/latest")

    sidebar.click_community_section_more_button
    sidebar.click_customize_community_section_button

    expect(section_modal).to have_no_localization_controls
  end

  it "hides translation controls when no other language is available" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en"
    SiteSetting.default_locale = "en"
    sidebar_section = Fabricate(:sidebar_section, title: "Docs", public: true, locale: "en")
    sidebar_url = Fabricate(:sidebar_url, name: "Guide", value: "/guide", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Docs")

    expect(section_modal).to have_no_source_language_control
    expect(section_modal).to have_no_localization_controls
  end

  it "keeps translation controls when only an existing translation needs managing" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en"
    SiteSetting.default_locale = "en"
    sidebar_section = Fabricate(:sidebar_section, title: "Docs", public: true, locale: "en")
    sidebar_url = Fabricate(:sidebar_url, name: "Guide", value: "/guide", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)
    Fabricate(:sidebar_section_localization, sidebar_section:, locale: "ja", title: "ドキュメント")

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Docs")
    section_modal.open_translations

    expect(section_modal).to have_translation_language("ja")
    expect(section_modal).to have_no_add_language
  end

  it "does not offer the default locale as a translation target" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.default_locale = "en"
    SiteSetting.content_localization_supported_locales = "en|ja"
    sidebar_section =
      Fabricate(:sidebar_section, title: "Public section", public: true, locale: "en")
    sidebar_url = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Public section")
    section_modal.open_translations
    section_modal.add_language("ja")

    expect(section_modal).to have_locale_option("ja")
    expect(section_modal).to have_no_locale_option(SiteSetting.default_locale)
  end

  it "excludes the section's own source language, not the site default, from translation targets" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|ja"
    SiteSetting.default_locale = "en"
    sidebar_section =
      Fabricate(:sidebar_section, title: "Public section", public: true, locale: "ja")
    sidebar_url = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags", locale: "ja")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Public section")

    expect(section_modal).to have_source_language("ja")

    section_modal.open_translations
    section_modal.add_language("en")
    expect(section_modal).to have_locale_option("en")
    expect(section_modal).to have_no_locale_option("ja")

    section_modal.close_translations
    section_modal.select_source_language("en")
    section_modal.open_translations
    section_modal.add_language("ja")

    expect(section_modal).to have_locale_option("ja")
    expect(section_modal).to have_no_locale_option("en")
  end

  it "hides a link translation that collides with the section's source language" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|ja"
    SiteSetting.default_locale = "en"
    sidebar_section = Fabricate(:sidebar_section, title: "Docs", public: true, locale: "en")
    sidebar_url = Fabricate(:sidebar_url, name: "Guide", value: "/guide", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)
    Fabricate(:sidebar_url_localization, sidebar_url:, locale: "ja", name: "ガイド")

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Docs")
    section_modal.open_translations

    expect(section_modal).to have_translation_row("ja", "Guide")

    section_modal.close_translations
    section_modal.select_source_language("ja")
    section_modal.open_translations

    expect(section_modal).to have_no_translation_language("ja")
  end

  it "keeps a link's own source language when the section is saved" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|ja"
    SiteSetting.default_locale = "en"
    sidebar_section = Fabricate(:sidebar_section, title: "Docs", public: true, locale: "en")
    sidebar_url = Fabricate(:sidebar_url, name: "ガイド", value: "/guide", locale: "ja")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)
    Fabricate(:sidebar_url_localization, sidebar_url:, locale: "en", name: "Guide")

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Docs")
    section_modal.fill_name("Documentation")
    section_modal.save
    section_modal.confirm_update

    expect(section_modal).to be_closed
    expect(sidebar_url.reload.locale).to eq("ja")
    expect(sidebar_url.localizations.pluck(:locale, :name)).to eq([%w[en Guide]])
  end

  it "keeps an existing translation when the source language is toggled away and back" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|fr"
    SiteSetting.default_locale = "en"
    sidebar_section = Fabricate(:sidebar_section, title: "Docs", public: true, locale: "en")
    sidebar_url = Fabricate(:sidebar_url, name: "Guide", value: "/guide", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)
    Fabricate(:sidebar_section_localization, sidebar_section:, locale: "fr", title: "Docs FR")

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Docs")

    section_modal.select_source_language("fr")
    section_modal.select_source_language("en")
    section_modal.save
    section_modal.confirm_update

    expect(section_modal).to be_closed
    expect(sidebar_section.reload.localizations.pluck(:locale, :title)).to eq([["fr", "Docs FR"]])
  end

  it "edits the section title and every link name for one language at a time" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|fr"
    SiteSetting.default_locale = "en"
    sidebar_section = Fabricate(:sidebar_section, title: "Docs", public: true, locale: "en")
    guide = Fabricate(:sidebar_url, name: "Guide", value: "/guide", locale: "en")
    api = Fabricate(:sidebar_url, name: "API", value: "/api", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: guide)
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: api)

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Docs")
    section_modal.open_translations
    section_modal.add_language("fr")

    section_modal.fill_translation("fr", "Docs", "Documentation")
    section_modal.fill_translation("fr", "Guide", "Guide FR")
    section_modal.save
    section_modal.confirm_update

    expect(section_modal).to be_closed
    expect(sidebar_section.reload.localizations.pluck(:locale, :title)).to eq(
      [%w[fr Documentation]],
    )
    expect(guide.reload.localizations.pluck(:locale, :name)).to eq([["fr", "Guide FR"]])
    expect(api.reload.localizations).to be_empty
  end

  it "labels a group by its own language when a link has a different source" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|hu|ja|fr"
    SiteSetting.default_locale = "en"
    sidebar_section = Fabricate(:sidebar_section, title: "Docs", public: true, locale: "en")
    guide = Fabricate(:sidebar_url, name: "Guide", value: "/guide", locale: "en")
    guide_ja = Fabricate(:sidebar_url, name: "ガイド v2", value: "/guide-2", locale: "ja")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: guide)
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: guide_ja)
    Fabricate(:sidebar_url_localization, sidebar_url: guide, locale: "ja", name: "ガイド")
    Fabricate(:sidebar_url_localization, sidebar_url: guide_ja, locale: "en", name: "Guide v2")

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Docs")
    section_modal.open_translations

    expect(section_modal).to have_translation_language("en")
    expect(section_modal).to have_selected_translation_language("en")
    expect(section_modal).to have_translation_row("en", "ガイド v2")
    expect(section_modal).to have_no_translation_row("en", "Guide")
  end

  it "stops offering languages once every target is used" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|hu|ja"
    SiteSetting.default_locale = "en"
    sidebar_section = Fabricate(:sidebar_section, title: "Docs", public: true, locale: "en")
    guide = Fabricate(:sidebar_url, name: "Guide", value: "/guide", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: guide)

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Docs")
    section_modal.open_translations
    section_modal.add_language("hu")
    section_modal.add_language("ja")

    expect(section_modal).to have_translation_languages(2)
    expect(section_modal).to have_no_add_language
  end

  it "offers link translations in the same session a section is made public" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|ja"
    SiteSetting.default_locale = "en"
    sidebar_section =
      Fabricate(:sidebar_section, title: "Drafts", public: false, user: admin, locale: "en")
    scratch = Fabricate(:sidebar_url, name: "Scratch", value: "/scratch", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: scratch)

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Drafts")
    section_modal.mark_as_public
    section_modal.open_translations
    section_modal.add_language("ja")

    expect(section_modal).to have_translation_row("ja", "Scratch")

    section_modal.fill_translation("ja", "Scratch", "スクラッチ")
    section_modal.save
    section_modal.confirm_update

    expect(section_modal).to be_closed
    expect(scratch.reload.localizations.pluck(:locale, :name)).to eq([%w[ja スクラッチ]])
  end

  it "confirms before removing a translation that was cleared" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|fr"
    SiteSetting.default_locale = "en"
    sidebar_section = Fabricate(:sidebar_section, title: "Docs", public: true, locale: "en")
    guide = Fabricate(:sidebar_url, name: "Guide", value: "/guide", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: guide)
    Fabricate(:sidebar_section_localization, sidebar_section:, locale: "fr", title: "Documentation")

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Docs")
    section_modal.open_translations
    section_modal.fill_translation("fr", "Docs", "")
    section_modal.save

    expect(page).to have_css(
      ".dialog-body",
      text: I18n.t("js.sidebar.sections.custom.localizations.remove_cleared_confirm", count: 1),
    )

    section_modal.confirm_update

    expect(section_modal).to be_closed
    expect(sidebar_section.reload.localizations).to be_empty
  end

  it "removes every translation for a language at once" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|fr"
    SiteSetting.default_locale = "en"
    sidebar_section = Fabricate(:sidebar_section, title: "Docs", public: true, locale: "en")
    guide = Fabricate(:sidebar_url, name: "Guide", value: "/guide", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: guide)
    Fabricate(:sidebar_section_localization, sidebar_section:, locale: "fr", title: "Documentation")
    Fabricate(:sidebar_url_localization, sidebar_url: guide, locale: "fr", name: "Guide FR")

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Docs")
    section_modal.open_translations

    expect(section_modal).to have_translation_languages(1)

    section_modal.remove_language("fr")
    section_modal.confirm_dialog

    expect(section_modal).to have_translation_languages(0)

    section_modal.save
    section_modal.confirm_update

    expect(section_modal).to be_closed
    expect(sidebar_section.reload.localizations).to be_empty
    expect(guide.reload.localizations).to be_empty
  end

  it "does not allow duplicate section title translation locales" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.default_locale = "en"
    SiteSetting.content_localization_supported_locales = "en|zh_CN|ja"
    sidebar_section =
      Fabricate(:sidebar_section, title: "Public section", public: true, locale: "en")
    sidebar_url = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)

    sign_in admin
    visit("/latest")

    sidebar.edit_custom_section("Public section")
    section_modal.open_translations
    section_modal.add_language("zh_CN")
    section_modal.add_language("ja")

    expect(section_modal).to have_translation_languages(2)
    expect(section_modal).to have_disabled_translation_locale("zh_CN", "ja")
    expect(section_modal).to have_disabled_translation_locale("ja", "zh_CN")
    expect(section_modal).to have_no_add_language
  end

  it "displays warning when public section is marked as private" do
    sign_in admin
    visit("/latest")
    sidebar.click_add_section_button

    section_modal.fill_name("Public section")
    section_modal.fill_link("Sidebar Tags", "/tags")
    section_modal.mark_as_public
    section_modal.save

    expect(section_modal).to be_closed

    sidebar.edit_custom_section("Public section")
    section_modal.fill_name("Edited public section")
    section_modal.mark_as_public
    section_modal.save

    expect(section_modal).to have_text(
      "This section is visible to everyone. After the update, it will be visible only to you. Are you sure?",
    )

    section_modal.confirm_update

    expect(section_modal).to be_closed
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

  it "navigates to tag page when clicking a legacy category+tag link without tag_id" do
    SiteSetting.tagging_enabled = true
    category = Fabricate(:category)
    tag = Fabricate(:tag)
    Fabricate(:topic, category: category, tags: [tag])

    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    sidebar_url =
      Fabricate(
        :sidebar_url,
        name: "Tagged",
        value: "/tags/c/#{category.slug}/#{category.id}/#{tag.name}?status=closed",
      )
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)

    sign_in user
    visit("/latest")

    sidebar.click_section_link("Tagged")

    expect(page).to have_current_path(
      "/tags/c/#{category.slug}/#{category.id}/#{tag.slug}/#{tag.id}?status=closed",
    )
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
