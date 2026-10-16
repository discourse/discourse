# frozen_string_literal: true

describe "Custom sidebar sections" do
  fab!(:user)
  fab!(:admin)
  let(:section_modal) { PageObjects::Modals::SidebarSectionForm.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { user.user_option.update!(external_links_in_new_tab: true) }

  shared_examples "creating custom sections" do |relative_root_url|
    it "allows the user to create custom section" do
      browser_page
        .goto("#{relative_root_url}/latest")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(sidebar).to have_no_add_section_button

      sign_in user
      browser_page
        .goto("#{relative_root_url}/latest")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      sidebar.click_add_section_button

      expect(section_modal).to RSpecPredicates.be_visible
      expect(section_modal).to have_disabled_save
      expect(section_modal).to have_section_links_label
      expect(sidebar.custom_section_modal_title).to contain_text(
        browser_text_pattern("Add custom section"),
        useInnerText: true,
      )

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

  it "allows the user to create sections with different link formats" do
    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.click_add_section_button
    section_modal.fill_name("Preferences section")
    section_modal.fill_link("My preferences", "/my/preferences")
    section_modal.save

    expect(section_modal).to be_closed
    expect(sidebar).to have_section("Preferences section")
    expect(sidebar).to have_section_link("My preferences", target: "_self")

    sidebar.click_add_section_button
    section_modal.fill_name("Published page section")
    section_modal.fill_link("Published Page", "/pub/test")
    section_modal.save

    expect(section_modal).to be_closed
    expect(sidebar).to have_section("Published page section")
    expect(sidebar).to have_section_link("Published Page", target: "_self")

    sidebar.click_add_section_button

    expect(section_modal).to RSpecPredicates.be_visible
    expect(section_modal).to have_disabled_save
    expect(sidebar.custom_section_modal_title).to contain_text(
      browser_text_pattern("Add custom section"),
      useInnerText: true,
    )

    section_modal.fill_name("External link section")

    section_modal.fill_link("Discourse Homepage", "https://discourse.org")
    expect(section_modal).to have_enabled_save

    section_modal.save

    expect(section_modal).to be_closed
    expect(sidebar).to have_section("External link section")
    expect(sidebar).to have_section_link(
      "Discourse Homepage",
      href: "https://discourse.org",
      target: "_blank",
    )

    sidebar.click_add_section_button

    expect(section_modal).to RSpecPredicates.be_visible
    expect(section_modal).to have_disabled_save
    expect(sidebar.custom_section_modal_title).to contain_text(
      browser_text_pattern("Add custom section"),
      useInnerText: true,
    )

    section_modal.fill_name("Anchor section")
    section_modal.fill_link("Faq", "/faq#anchor")
    section_modal.save

    expect(section_modal).to be_closed
    expect(sidebar).to have_section("Anchor section")
    expect(sidebar).to have_section_link("Faq", target: "_self", href: "/faq#anchor")

    sidebar.click_add_section_button

    expect(section_modal).to RSpecPredicates.be_visible
    expect(section_modal).to have_disabled_save
    expect(sidebar.custom_section_modal_title).to contain_text(
      browser_text_pattern("Add custom section"),
      useInnerText: true,
    )

    section_modal.fill_name("Query section")
    section_modal.fill_link("Faq", "/faq?a=b")
    section_modal.save

    expect(section_modal).to be_closed
    expect(sidebar).to have_section("Query section")
    expect(sidebar).to have_section_link("Faq", target: "_self", href: "/faq?a=b")

    sidebar.click_add_section_button

    expect(section_modal).to RSpecPredicates.be_visible
    expect(section_modal).to have_disabled_save
    expect(sidebar.custom_section_modal_title).to contain_text(
      browser_text_pattern("Add custom section"),
      useInnerText: true,
    )

    section_modal.fill_name("Heading section")
    section_modal.fill_link("Faq", "/faq#someheading")
    section_modal.save

    expect(section_modal).to be_closed
    expect(sidebar).to have_section("Heading section")
    expect(sidebar).to have_section_link("Faq", target: "_self", href: "/faq#someheading")
  end

  it "prioritizes exact url matches over ember routes" do
    sidebar_section = SidebarSection.find_by(section_type: "community")
    sidebar_url = Fabricate(:sidebar_url, name: "Topics", value: "/latest")
    sidebar_url_2 =
      Fabricate(:sidebar_url, name: "Sorted latest", value: "/latest?ascending=true&order=posts")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    sign_in user

    browser_page
      .goto("/latest?ascending=true&order=posts")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(sidebar).to have_exact_url_match_link("Sorted latest")
    expect(sidebar).to have_no_active_links
    expect(sidebar).to have_no_exact_url_match_link("everything")

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(sidebar).to have_active_link("everything")
    expect(sidebar).to have_no_exact_url_match_link("Sorted latest")
  end

  it "allows the user to create custom section with `/` path" do
    SiteSetting.top_menu = "read|posted|latest"

    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.click_add_section_button
    section_modal.fill_name("My section")
    section_modal.fill_link("Home", "/")
    section_modal.save

    expect(sidebar).to have_section("My section")
    expect(sidebar).to have_section_link("Home", href: "/")

    sidebar.click_section_link("Home")
    expect(
      browser_root.locator("#navigation-bar .active a[href='/read']").filter(visible: true),
    ).not_to have_count(0)
  end

  it "allows typing in the icon picker filter input" do
    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.click_add_section_button

    picker = section_modal.first_link_icon_picker
    picker.expand.type_filter("globe")

    expect(picker.filter_input.input_value).to eq("globe")
    expect(picker).to have_icon("globe")
  end

  it "accessibility - when new row is added in custom section, first new input is focused" do
    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.click_add_section_button
    sidebar.click_add_link_button

    is_focused =
      browser_page.evaluate(
        "function(arguments) { return document.activeElement.classList.contains('d-icon-grid-picker-trigger') }",
        arg: [],
      )

    expect(is_focused).to be true
  end

  it "accessibility - when customization modal is closed, trigger is refocused" do
    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.click_add_section_button
    section_modal.close

    expect(section_modal).to be_closed

    is_focused =
      browser_page.evaluate(
        "function(arguments) { return document.activeElement.classList.contains('add-section') }",
        arg: [],
      )

    expect(is_focused).to be true
  end

  it "allows the user to edit custom section" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    sidebar_url_2 = Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.edit_custom_section("My section")
    expect(browser_root.locator("#discourse-modal-title").filter(visible: true)).to contain_text(
      browser_text_pattern("Edit custom section"),
      useInnerText: true,
    )

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

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(sidebar.primary_section_links("my-section")).to eq(
      ["Sidebar Tags", "Sidebar Categories", "Sidebar Latest"],
    )

    sidebar.edit_custom_section("My section")

    tags_link =
      browser_root.locator(".draggable[data-link-name='Sidebar Tags']").filter(visible: true)
    latest_link =
      browser_root.locator(".draggable[data-link-name='Sidebar Latest']").filter(visible: true)
    drag_browser_element(source: tags_link, target: latest_link, delay_seconds: 0.4)
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

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.open_on_mobile
    sidebar.edit_custom_section("My section")

    expect(
      browser_root.locator(".sidebar-section-form-link .draggable").filter(visible: true),
    ).to have_count(0)
  end

  # TODO (ui-kit-reorderable-list-cleanup) fold these over the examples above
  # once the change ships.
  context "when enable_new_reordering_controls is enabled" do
    before { SiteSetting.enable_new_reordering_controls = true }

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
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      sidebar.edit_custom_section("My section")

      url_field = ".sidebar-section-form-link input[name='link-url']"
      # Leftwards and well past the field's edge: the press lands at its centre,
      # which for a short value is beyond the end of the text, so a short sweep
      # crosses no characters and would fail whether or not selection works. A
      # drag running off the edge still selects back to the start.
      drag_with_pointer(from: url_field, by: { x: -400 })

      expect(
        browser_page.evaluate(
          "function(arguments) { return #{
            "(() => { const i = document.querySelector(\"#{url_field}\"); " \
              "return i.selectionEnd - i.selectionStart; })()"
          } }",
          arg: [],
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
        Fabricate(
          :sidebar_url,
          name: "Sidebar Categories",
          value: "/categories",
        ).tap do |sidebar_url|
          Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
        end

      sidebar_url_3 =
        Fabricate(:sidebar_url, name: "Sidebar Latest", value: "/latest").tap do |sidebar_url|
          Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
        end

      sign_in user

      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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

      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      sidebar.edit_custom_section("My section")

      # Asserted before the move: without it, a run where the order already matched
      # would pass whether or not the arrow did anything.
      expect(section_modal.link_names).to eq(
        ["Sidebar Tags", "Sidebar Categories", "Sidebar Latest"],
      )

      section_modal.move_link_down("Sidebar Tags")

      try_until_success do
        expect(section_modal.link_names).to eq(
          ["Sidebar Categories", "Sidebar Tags", "Sidebar Latest"],
        )
      end

      # Focus is where the keyboard path lives or dies: the row moves in the DOM
      # under the pressed control, and a lost focus makes a second press
      # impossible.
      expect(section_modal.focused_link_name).to eq("Sidebar Tags")

      # So the second press goes through whatever holds focus, not through another
      # lookup by name, which would pass even if focus had been dropped.
      section_modal.press_focused_link_move_down

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

      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      sidebar.open_on_mobile
      sidebar.edit_custom_section("My section")

      # The handle renders on every viewport now that the drag begins on the grip
      # rather than anywhere on the row, so a press meant to scroll still scrolls.
      expect(
        browser_root.locator(".sidebar-section-form-link .draggable").filter(visible: true),
      ).not_to have_count(0)

      # Neither path substitutes for the other: the menu behind the handle is the
      # only route without a drag, and the drag is the only route without a
      # keyboard.
      section_modal.move_link_down("Sidebar Tags")

      try_until_success do
        expect(section_modal.link_names).to eq(["Sidebar Categories", "Sidebar Tags"])
      end
    end
  end

  it "reorders links in the sidebar with drag and drop" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags").tap do |sidebar_url|
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
    end
    Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories").tap do |sidebar_url|
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
    end

    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    rows = "[data-section-name='my-section'] li[data-sidebar-custom-link]"
    expect(browser_root.locator("#{rows}[data-drag-source]").filter(visible: true)).to have_count(2)
    # The row drags as a registered source, so its anchor must not drag too.
    # Checked on the rendered value: the binding only works as a real boolean.
    expect(
      browser_root.locator("#{rows} a[draggable='false']").filter(visible: true),
    ).to have_count(2)

    # Dropped below the target row's midpoint: its exact center sits on the
    # boundary the insertion index is measured against.
    drag_and_drop(
      source: "#{rows}:first-child",
      target: "#{rows}:last-child",
      target_position: {
        x: 30,
        y: 26,
      },
    )

    expect(
      browser_root.locator("#{rows}:first-child [data-link-name='Sidebar Categories']").filter(
        visible: true,
      ),
    ).not_to have_count(0)
    expect(sidebar.primary_section_links("my-section")).to eq(
      ["Sidebar Categories", "Sidebar Tags"],
    )
  end

  # The browser refuses a drop whose effect mismatches the row's `effectAllowed`,
  # with no `drop` event. A synthetic drag cannot see that, so this must be real.
  it "splits a link out into a new section by dropping it on the zone" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags").tap do |sidebar_url|
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
    end
    Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories").tap do |sidebar_url|
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
    end

    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    rows = "[data-section-name='my-section'] li[data-sidebar-custom-link]"
    expect(browser_root.locator("#{rows}[data-drag-source]").filter(visible: true)).to have_count(2)

    drag_and_hold(
      from: "#{rows}:first-child",
      over: ".sidebar-sections",
      to: ".sidebar-link-drop-target",
    ) do
      expect(
        browser_root.locator(".sidebar-link-drop-target:not(.is-arming)").filter(visible: true),
      ).not_to have_count(0)
    end

    expect(
      browser_root.locator(".sidebar-section-form-modal").filter(visible: true),
    ).not_to have_count(0)
    expect(browser_root.locator("input[name='link-name']").filter(visible: true).input_value).to eq(
      "Sidebar Tags",
    )

    browser_root.locator("input[name='section-name']").filter(visible: true).fill("Split out")
    browser_root.locator("#save-section").filter(visible: true).click

    expect(
      browser_root.locator("[data-section-name='split-out']").filter(visible: true),
    ).not_to have_count(0)
    expect(sidebar.primary_section_links("split-out")).to eq(["Sidebar Tags"])
    expect(sidebar.primary_section_links("my-section")).to eq(["Sidebar Categories"])
  end

  it "does not make sidebar links draggable on mobile", mobile: true do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags").tap do |sidebar_url|
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url)
    end

    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.open_on_mobile

    rows = "[data-section-name='my-section'] li[data-sidebar-custom-link]"
    expect(browser_root.locator(rows).filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator("#{rows}[data-drag-source]").filter(visible: true)).to have_count(0)
    # With no registered drag to make room for, the attribute is left off and
    # the anchor keeps the browser default.
    expect(browser_root.locator("#{rows} a[draggable]").filter(visible: true)).to have_count(0)
  end

  it "does not allow the user to edit public section" do
    sidebar_section = Fabricate(:sidebar_section, title: "Public section", public: true)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    sidebar_url_2 = Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(sidebar).to have_section("Public section")

    browser_root
      .locator(".sidebar-section[data-section-name='public-section']")
      .filter(visible: true)
      .hover

    expect(
      browser_root.locator(
        ".sidebar-section[data-section-name='public-section'] button.sidebar-section-header-button",
      ).filter(visible: true),
    ).to have_count(0)

    expect(
      browser_root.locator(
        ".sidebar-section[data-section-name='public-section'] .d-icon-globe",
      ).filter(visible: true),
    ).to have_count(0)
  end

  it "allows the user to delete custom section" do
    sidebar_section = Fabricate(:sidebar_section, title: "My section", user: user)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)

    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.edit_custom_section("My section")

    section_modal.delete
    expect(section_modal).to have_displayed_text("Are you sure you want to delete this section?")
    section_modal.confirm_delete

    expect(sidebar).to have_no_section("My section")
  end

  it "allows admin to create, edit and delete public section" do
    sign_in admin
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.click_add_section_button

    section_modal.fill_name("Public section")
    section_modal.fill_link("Sidebar Tags", "/tags")
    section_modal.mark_as_public
    section_modal.save

    expect(sidebar).to have_section("Public section")
    expect(sidebar).to have_section_link("Sidebar Tags")
    expect(
      browser_root.locator(
        ".sidebar-section[data-section-name='public-section'] .d-icon-globe",
      ).filter(visible: true),
    ).not_to have_count(0)

    sidebar.edit_custom_section("Public section")
    section_modal.fill_name("Edited public section")
    section_modal.save

    expect(section_modal).to have_displayed_text(
      "Changes will be visible to everyone on this site. Are you sure?",
    )

    section_modal.confirm_update

    expect(sidebar).to have_section("Edited public section")

    sidebar.edit_custom_section("Edited public section")
    section_modal.delete
    expect(section_modal).to have_displayed_text(
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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(".sidebar-section-header").filter(visible: true)).to contain_text(
      [browser_text_pattern("公開セクション")],
      useInnerText: true,
    )
    expect(browser_root.locator(".sidebar-section-link").filter(visible: true)).to contain_text(
      [browser_text_pattern("タグ")],
      useInnerText: true,
    )
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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(".sidebar-section-header").filter(visible: true)).to contain_text(
      [browser_text_pattern("公開セクション")],
      useInnerText: true,
    )
    expect(browser_root.locator(".sidebar-section-link").filter(visible: true)).to contain_text(
      [browser_text_pattern("タグ")],
      useInnerText: true,
    )

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.edit_custom_section("Public section")

    expect(section_modal).to have_localization_controls

    section_modal.mark_as_public

    expect(section_modal).to have_no_localization_controls
  end

  it "does not show translation controls for the built-in community section" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "ja"

    sign_in admin
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    expect(api.reload.localizations).to RSpecPredicates.be_empty
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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.edit_custom_section("Docs")
    section_modal.open_translations
    section_modal.fill_translation("fr", "Docs", "")
    section_modal.save

    expect(browser_root.locator(".dialog-body").filter(visible: true)).to contain_text(
      [
        browser_text_pattern(
          I18n.t("js.sidebar.sections.custom.localizations.remove_cleared_confirm", count: 1),
        ),
      ],
      useInnerText: true,
    )

    section_modal.confirm_update

    expect(section_modal).to be_closed
    expect(sidebar_section.reload.localizations).to RSpecPredicates.be_empty
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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.edit_custom_section("Docs")
    section_modal.open_translations

    expect(section_modal).to have_translation_languages(1)

    section_modal.remove_language("fr")
    section_modal.confirm_dialog

    expect(section_modal).to have_translation_languages(0)

    section_modal.save
    section_modal.confirm_update

    expect(section_modal).to be_closed
    expect(sidebar_section.reload.localizations).to RSpecPredicates.be_empty
    expect(guide.reload.localizations).to RSpecPredicates.be_empty
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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
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

    expect(section_modal).to have_displayed_text(
      "This section is visible to everyone. After the update, it will be visible only to you. Are you sure?",
    )

    section_modal.confirm_update

    expect(section_modal).to be_closed
    expect(sidebar).to have_section("Edited public section")
    expect(
      browser_root.locator(
        ".sidebar-section[data-section-name='edited-public-section'] .d-icon-globe",
      ).filter(visible: true),
    ).to have_count(0)
  end

  it "shows anonymous public sections" do
    sidebar_section = Fabricate(:sidebar_section, title: "Public section", public: true)
    sidebar_url_1 = Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    sidebar_url_2 = Fabricate(:sidebar_url, name: "Sidebar Categories", value: "/categories")
    Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.click_section_link("Tagged")

    expect(browser_page).to have_url(
      "/tags/c/#{category.slug}/#{category.id}/#{tag.slug}/#{tag.id}?status=closed",
    )
  end

  it "validates custom section fields" do
    sign_in user
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.click_add_section_button

    section_modal.fill_name("A" * (SidebarSection::MAX_TITLE_LENGTH + 1))
    section_modal.fill_link("B" * (SidebarUrl::MAX_NAME_LENGTH + 1), "https:")

    expect(browser_root.locator(".title.warning").filter(visible: true)).to contain_text(
      browser_text_pattern("Title must be shorter than 30 characters"),
      useInnerText: true,
    )
    expect(browser_root.locator(".name.warning").filter(visible: true)).to contain_text(
      browser_text_pattern("Name must be shorter than 80 characters"),
      useInnerText: true,
    )
    expect(browser_root.locator(".value.warning").filter(visible: true)).to contain_text(
      browser_text_pattern("Format is invalid"),
      useInnerText: true,
    )

    section_modal.fill_name("")
    section_modal.fill_link("", "")
    expect(browser_root.locator(".title.warning").filter(visible: true)).to contain_text(
      browser_text_pattern("Title cannot be blank"),
      useInnerText: true,
    )
    expect(browser_root.locator(".name.warning").filter(visible: true)).to contain_text(
      browser_text_pattern("Name cannot be blank"),
      useInnerText: true,
    )
    expect(browser_root.locator(".value.warning").filter(visible: true)).to contain_text(
      browser_text_pattern("Link cannot be blank"),
      useInnerText: true,
    )

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

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
