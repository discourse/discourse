# frozen_string_literal: true

describe "Admin Customize Theme Show Config Area Page", type: :system do
  fab!(:admin)

  fab!(:basic_theme) do
    Fabricate(
      :theme,
      name: "Basic Theme",
      user: Fabricate(:user, username: "theme_creator"),
      user_selectable: false,
      auto_update: false,
    )
  end

  fab!(:complete_theme) do
    theme =
      Fabricate(
        :theme,
        name: "Complete Theme",
        user_selectable: true,
        auto_update: true,
        theme_fields: [
          ThemeField.new(
            name: "en",
            type_id: ThemeField.types[:yaml],
            target_id: Theme.targets[:translations],
            value: <<~YAML,
            en:
              something_blah: "Hello"
              theme_metadata:
                description: "A theme with all the features"
          YAML
          ),
        ],
      )

    color_scheme = Fabricate(:color_scheme, theme_id: theme.id)
    theme.color_scheme_id = color_scheme.id
    theme.save!

    theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
      background_color:
        default: "#FFF"
        description: "Background color"
    YAML

    theme.set_field(target: :common, name: :scss, value: "body { color: red; }")

    theme.set_field(
      target: :extra_js,
      name: "discourse/lib/extra.js.es6",
      value: "console.log('extra');",
    )

    theme.save!
    theme
  end

  fab!(:remote_theme) do
    Fabricate(
      :theme,
      name: "Remote Theme",
      remote_theme:
        Fabricate(
          :remote_theme,
          remote_url: "https://github.com/discourse/discourse-theme",
          about_url: "https://meta.discourse.org/about",
          license_url: "https://github.com/discourse/discourse-theme/LICENSE",
          theme_version: "1.0.0",
          local_version: "a5d6aa968275ae1caa228630b78049f6",
          remote_version: "eaa377e40fc295e2fb5adb9b8a60fc4a",
        ),
    )
  end

  fab!(:parent_theme) do
    Fabricate(
      :theme,
      name: "Parent Theme",
      child_themes: [Fabricate(:theme, name: "Child Component", component: true)],
    )
  end

  before { sign_in(admin) }

  context "with a basic theme" do
    let(:theme_page) { PageObjects::Pages::AdminCustomizeThemeShowConfigArea.new(basic_theme.id) }

    it "shows basic theme information" do
      theme_page.visit

      expect(theme_page).to have_theme_name("Basic Theme")
      expect(theme_page).to have_created_by_section
      expect(theme_page).to have_no_description
      expect(theme_page).to have_no_colors_card
      expect(theme_page).to have_no_settings_card
      expect(theme_page).to have_no_translations_card
      expect(theme_page).to have_uploads_card
      expect(theme_page).to have_no_remote_theme_metadata
      expect(theme_page).to have_no_version_metadata
      expect(theme_page).to have_no_extra_files_section
    end
  end

  context "with a complete theme" do
    let(:theme_page) do
      PageObjects::Pages::AdminCustomizeThemeShowConfigArea.new(complete_theme.id)
    end

    it "shows all theme information sections" do
      theme_page.visit

      expect(theme_page).to have_theme_name("Complete Theme")
      expect(theme_page).to have_description("A theme with all the features")
      expect(theme_page).to have_colors_card
      expect(theme_page).to have_settings_card
      expect(theme_page).to have_translations_card
      expect(theme_page).to have_uploads_card
      expect(theme_page).to have_custom_css_html_section
      expect(theme_page).to have_extra_files_section
    end
  end

  context "with a remote theme" do
    let(:theme_page) { PageObjects::Pages::AdminCustomizeThemeShowConfigArea.new(remote_theme.id) }

    it "shows remote theme metadata" do
      theme_page.visit

      expect(theme_page).to have_theme_name("Remote Theme")
      expect(theme_page).to have_no_created_by_section
      expect(theme_page).to have_remote_theme_metadata
      expect(theme_page).to have_version_metadata
      expect(theme_page).to have_local_version("a5d6aa")
      expect(theme_page).to have_last_updated_metadata
      expect(theme_page).to have_theme_storage_metadata
      expect(theme_page).to have_no_uploads_card
    end
  end

  context "with a parent theme" do
    let(:theme_page) { PageObjects::Pages::AdminCustomizeThemeShowConfigArea.new(parent_theme.id) }

    it "shows child components section" do
      theme_page.visit

      expect(theme_page).to have_theme_name("Parent Theme")
      expect(theme_page).to have_components_with_children
      expect(theme_page).to have_child_component(parent_theme.child_themes.first)
    end
  end
end
