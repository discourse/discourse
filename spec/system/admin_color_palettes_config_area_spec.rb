# frozen_string_literal: true

describe "Admin Color Palettes Config Area Page" do
  fab!(:admin) { Fabricate(:admin, locale: "en") }
  fab!(:palette) { Fabricate(:color_scheme, user_selectable: false, name: "A Test Palette") }
  fab!(:theme) { Fabricate(:theme, name: "Test Theme") }
  fab!(:user_selectable_palette) do
    Fabricate(:color_scheme, name: "User Selectable", user_selectable: true)
  end
  fab!(:theme_palette) { Fabricate(:color_scheme, name: "Theme Palette", theme: theme) }
  fab!(:regular_palette) do
    Fabricate(:color_scheme, name: "Regular Palette", user_selectable: false)
  end

  let(:foundation_scheme_a) do
    Fabricate(:color_scheme, name: "Foundation scheme a", theme: Theme.foundation_theme)
  end
  let(:foundation_scheme_b) do
    Fabricate(:color_scheme, name: "Foundation scheme b", theme: Theme.foundation_theme)
  end
  let(:horizon_scheme_a) do
    Fabricate(:color_scheme, name: "Horizon scheme a", theme: Theme.horizon_theme)
  end
  let(:horizon_scheme_b) do
    Fabricate(:color_scheme, name: "Horizon scheme b", theme: Theme.horizon_theme)
  end
  let(:custom_scheme_a) { Fabricate(:color_scheme, name: "Custom scheme a") }
  let(:custom_scheme_b) { Fabricate(:color_scheme, name: "Custom scheme b") }
  let(:selectable_foundation_scheme_a) do
    Fabricate(
      :color_scheme,
      name: "Selectable foundation scheme a",
      theme: Theme.foundation_theme,
      user_selectable: true,
    )
  end
  let(:selectable_foundation_scheme_b) do
    Fabricate(
      :color_scheme,
      name: "Selectable foundation scheme b",
      theme: Theme.foundation_theme,
      user_selectable: true,
    )
  end
  let(:selectable_horizon_theme_scheme_a) do
    Fabricate(
      :color_scheme,
      name: "Selectable horizon scheme a",
      theme: Theme.horizon_theme,
      user_selectable: true,
    )
  end
  let(:selectable_horizon_theme_scheme_b) do
    Fabricate(
      :color_scheme,
      name: "Selectable horizon scheme b",
      theme: Theme.horizon_theme,
      user_selectable: true,
    )
  end
  let(:selectable_custom_scheme_a) do
    Fabricate(:color_scheme, name: "Selectable custom scheme a", user_selectable: true)
  end
  let(:selectable_custom_scheme_b) do
    Fabricate(:color_scheme, name: "Selectable custom scheme b", user_selectable: true)
  end
  let(:default_light_scheme) { Fabricate(:color_scheme, name: "Default light") }
  let(:default_dark_scheme) { Fabricate(:color_scheme, name: "Default dark") }

  let(:config_area) { PageObjects::Pages::AdminColorPalettesConfigArea.new }
  let(:create_color_palette_modal) { PageObjects::Modals::CreateColorPalette.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before { sign_in(admin) }

  it "can create new color palettes" do
    config_area.visit

    config_area.create_button.click
    create_color_palette_modal.base_dropdown.select_row_by_name("Grey Amber")
    create_color_palette_modal.create_button.click

    expect(browser_page).to PlaywrightMatchers.have_url(%r{/admin/config/colors/\d+})
  end

  it "can create new color palette from custom palette" do
    config_area.visit

    config_area.create_button.click
    create_color_palette_modal.base_dropdown.expand
    expect(
      browser_root.locator(".color-palette-picker-row").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    create_color_palette_modal.base_dropdown.select_row_by_name("A Test Palette")

    create_color_palette_modal.create_button.click

    expect(browser_page).to PlaywrightMatchers.have_url(%r{/admin/config/colors/\d+})
    expect(browser_root.locator(".revert").filter(visible: true)).to PlaywrightMatchers.have_count(
      0,
    )
  end

  describe "filtering" do
    it "shows filters when there are more than 8 color schemes" do
      config_area.visit

      expect(
        browser_root.locator(".d-filter-controls__input").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "can filter by text search" do
      config_area.visit

      browser_root
        .locator(".d-filter-controls__input")
        .filter(visible: true)
        .fill(user_selectable_palette.name)

      expect(
        browser_root.locator("[data-palette-id='#{user_selectable_palette.id}']").filter(
          visible: true,
        ),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "can filter by type" do
      config_area.visit

      select_kit = PageObjects::Components::DNativeSelect.new(".d-native-select")
      select_kit.select("user_selectable")

      expect(
        browser_root.locator("[data-palette-id='#{user_selectable_palette.id}']").filter(
          visible: true,
        ),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".color-palette:not([data-palette-id])").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "shows no results state" do
      config_area.visit

      browser_root.locator(".d-filter-controls__input").filter(visible: true).fill("bananas")

      expect(
        browser_root.locator(".d-filter-controls__no-results").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("button").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern(I18n.t("js.filter_controls.reset"))],
        useInnerText: true,
      )
    end
  end

  describe "color palette list items" do
    it "shows palette details" do
      config_area.visit

      expect(
        browser_root.locator("[data-palette-id='#{user_selectable_palette.id}']").filter(
          visible: true,
        ),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("[data-palette-id='#{theme_palette.id}']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "shows user selectable badge" do
      config_area.visit

      within_browser(
        browser_root.locator("[data-palette-id='#{user_selectable_palette.id}']").filter(
          visible: true,
        ),
      ) do
        expect(
          browser_root.locator(".theme-card__badge.--selectable").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end

    it "shows theme link for theme palettes" do
      config_area.visit

      within_browser(
        browser_root.locator("[data-palette-id='#{theme_palette.id}']").filter(visible: true),
      ) do
        expect(
          browser_root
            .get_by_role("link")
            .and(
              browser_root.locator(
                "[id=#{theme.name.to_s.to_json}], [name=#{theme.name.to_s.to_json}]",
              ).or(browser_root.get_by_role("link", name: theme.name)),
            )
            .filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end

    it "can toggle user selectable status" do
      config_area.visit

      within_browser(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ) { browser_root.locator(".btn-flat").filter(visible: true).click }

      expect(
        browser_root.locator(".dropdown-menu").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      browser_root
        .locator(
          "[id=#{I18n.t("admin_js.admin.customize.theme.user_selectable_button_label").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.user_selectable_button_label").to_s.to_json}]",
        )
        .or(
          browser_root.get_by_role(
            "button",
            name: I18n.t("admin_js.admin.customize.theme.user_selectable_button_label"),
          ),
        )
        .filter(visible: true)
        .click

      within_browser(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ) do
        expect(
          browser_root.locator(".theme-card__badge.--selectable").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end

    it "can set as light and dark default for theme" do
      config_area.visit

      within_browser(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ) { browser_root.locator(".btn-flat").filter(visible: true).click }

      expect(
        browser_root.locator(".dropdown-menu").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_root
        .locator(
          "[id=#{
            I18n
              .t(
                "admin_js.admin.customize.colors.set_default_light",
                { theme: Theme.find_default.name },
              )
              .to_s
              .to_json
          }], [name=#{
            I18n
              .t(
                "admin_js.admin.customize.colors.set_default_light",
                { theme: Theme.find_default.name },
              )
              .to_s
              .to_json
          }]",
        )
        .or(
          browser_root.get_by_role(
            "button",
            name:
              I18n.t(
                "admin_js.admin.customize.colors.set_default_light",
                { theme: Theme.find_default.name },
              ),
          ),
        )
        .filter(visible: true)
        .click

      within_browser(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ) do
        expect(
          browser_root.locator(".theme-card__badge.--default").filter(visible: true),
        ).to PlaywrightMatchers.contain_text(
          [
            browser_text_pattern(
              I18n.t("admin_js.admin.customize.colors.default_light_badge.text"),
            ),
          ],
          useInnerText: true,
        )
      end

      within_browser(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ) { browser_root.locator(".btn-flat").filter(visible: true).click }

      expect(
        browser_root.locator(".dropdown-menu").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_root
        .locator(
          "[id=#{
            I18n
              .t(
                "admin_js.admin.customize.colors.set_default_dark",
                { theme: Theme.find_default.name },
              )
              .to_s
              .to_json
          }], [name=#{
            I18n
              .t(
                "admin_js.admin.customize.colors.set_default_dark",
                { theme: Theme.find_default.name },
              )
              .to_s
              .to_json
          }]",
        )
        .or(
          browser_root.get_by_role(
            "button",
            name:
              I18n.t(
                "admin_js.admin.customize.colors.set_default_dark",
                { theme: Theme.find_default.name },
              ),
          ),
        )
        .filter(visible: true)
        .click

      within_browser(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ) do
        expect(
          browser_root.locator(".theme-card__badge.--default").filter(visible: true),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("admin_js.admin.customize.colors.default_dark_badge.text"))],
          useInnerText: true,
        )
      end
    end
  end

  describe "CSS variables" do
    it "generates CSS variables for color schemes" do
      config_area.visit

      palette_item =
        browser_root.locator(
          "[data-palette-id='#{regular_palette.id}'] .color-palette__preview",
        ).filter(visible: true)

      expect(palette_item.get_attribute("style")).to include("--primary--preview:")
      expect(palette_item.get_attribute("style")).to include("--secondary--preview:")
      expect(palette_item.get_attribute("style")).to include("--tertiary--preview:")
    end
  end

  describe "live preview functionality" do
    it "does not show toast when live preview is available" do
      admin.user_option.update!(
        theme_ids: [Theme.find_default.id],
        color_scheme_id: -1,
        dark_scheme_id: -1,
      )

      config_area.visit

      within_browser(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ) { browser_root.locator(".btn-flat").filter(visible: true).click }

      expect(
        browser_root.locator(".dropdown-menu").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_root
        .locator(
          "[id=#{
            I18n
              .t(
                "admin_js.admin.customize.colors.set_default_light",
                { theme: Theme.find_default.name },
              )
              .to_s
              .to_json
          }], [name=#{
            I18n
              .t(
                "admin_js.admin.customize.colors.set_default_light",
                { theme: Theme.find_default.name },
              )
              .to_s
              .to_json
          }]",
        )
        .or(
          browser_root.get_by_role(
            "button",
            name:
              I18n.t(
                "admin_js.admin.customize.colors.set_default_light",
                { theme: Theme.find_default.name },
              ),
          ),
        )
        .filter(visible: true)
        .click

      expect(
        browser_root.locator(".fk-d-default-toast.-success").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "shows toast when admin cannot see live preview" do
      custom_scheme = Fabricate(:color_scheme, name: "Custom Scheme", user_selectable: true)
      admin.user_option.update!(
        theme_ids: [Theme.find_default.id],
        color_scheme_id: custom_scheme.id,
      )

      config_area.visit

      within_browser(
        browser_root.locator("[data-palette-id='#{regular_palette.id}']").filter(visible: true),
      ) { browser_root.locator(".btn-flat").filter(visible: true).click }

      expect(
        browser_root.locator(".dropdown-menu").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_root
        .locator(
          "[id=#{
            I18n
              .t(
                "admin_js.admin.customize.colors.set_default_light",
                { theme: Theme.find_default.name },
              )
              .to_s
              .to_json
          }], [name=#{
            I18n
              .t(
                "admin_js.admin.customize.colors.set_default_light",
                { theme: Theme.find_default.name },
              )
              .to_s
              .to_json
          }]",
        )
        .or(
          browser_root.get_by_role(
            "button",
            name:
              I18n.t(
                "admin_js.admin.customize.colors.set_default_light",
                { theme: Theme.find_default.name },
              ),
          ),
        )
        .filter(visible: true)
        .click

      expected_message =
        I18n.t(
          "admin_js.admin.customize.colors.set_default_success",
          schemeName: regular_palette.name,
          themeName: Theme.find_default.name,
        )
      expect(toasts).to have_success(expected_message)
    end
  end

  describe "sort" do
    before do
      ColorScheme.delete_all
      foundation_scheme_a
      foundation_scheme_b
      horizon_scheme_a
      horizon_scheme_b
      custom_scheme_a
      custom_scheme_b
      selectable_foundation_scheme_a
      selectable_foundation_scheme_b
      selectable_horizon_theme_scheme_a
      selectable_horizon_theme_scheme_b
      selectable_custom_scheme_a
      selectable_custom_scheme_b
      default_light_scheme
      default_dark_scheme
      Theme.horizon_theme.update!(
        color_scheme: default_light_scheme,
        dark_color_scheme: default_dark_scheme,
      )
    end

    it "sorts schemes in order: selectable, custom, current default theme, alphabetical for horizon theme" do
      SiteSetting.default_theme_id = Theme.horizon_theme.id
      config_area.visit
      color_schemes =
        browser_root
          .locator(".color-palette__details h3")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |element| element.inner_text.strip }
      expect(color_schemes).to eq(
        [
          "Default light",
          "Default dark",
          "Selectable custom scheme a",
          "Selectable custom scheme b",
          "Selectable horizon scheme a",
          "Selectable horizon scheme b",
          "Selectable foundation scheme a",
          "Selectable foundation scheme b",
          "Custom scheme a",
          "Custom scheme b",
          "Horizon scheme a",
          "Horizon scheme b",
          "Foundation scheme a",
          "Foundation scheme b",
          I18n.t("admin_js.admin.customize.theme.default_light_scheme"),
        ],
      )
    end

    it "sorts schemes in order: selectable, custom, current default theme, alphabetical for foundation theme" do
      SiteSetting.default_theme_id = Theme.foundation_theme.id
      config_area.visit
      color_schemes =
        browser_root
          .locator(".color-palette__details h3")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |element| element.inner_text.strip }
      expect(color_schemes).to eq(
        [
          I18n.t("admin_js.admin.customize.theme.default_light_scheme"),
          "Selectable custom scheme a",
          "Selectable custom scheme b",
          "Selectable foundation scheme a",
          "Selectable foundation scheme b",
          "Selectable horizon scheme a",
          "Selectable horizon scheme b",
          "Custom scheme a",
          "Custom scheme b",
          "Default dark",
          "Default light",
          "Foundation scheme a",
          "Foundation scheme b",
          "Horizon scheme a",
          "Horizon scheme b",
        ],
      )
    end
  end
end
