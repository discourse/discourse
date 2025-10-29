# frozen_string_literal: true

RSpec.describe "tasks/migrate_advanced_search_banner_to_welcome_banner" do
  before do
    Rake::Task.clear
    load Rails.root.join("lib/tasks/migrate_advanced_search_banner_to_welcome_banner.rake")
  end

  describe "#validate_and_get_db" do
    it "returns the database name if it exists" do
      db = "default"
      RailsMultisite::ConnectionManagement.stubs(:has_db?).with(db).returns(true)

      result = validate_and_get_db(db)

      expect(result).to eq(db)
    end

    it "returns default database when provided database does not exist" do
      db = "nonexistent"
      default_db = RailsMultisite::ConnectionManagement::DEFAULT
      RailsMultisite::ConnectionManagement.stubs(:has_db?).with(db).returns(false)

      result = validate_and_get_db(db)

      expect(result).to eq(default_db)
    end
  end

  describe "#wrap_themes_with_db" do
    it "wraps themes with database information" do
      theme1 = Fabricate(:theme)
      theme2 = Fabricate(:theme)
      db = "default"

      result = wrap_themes_with_db([theme1, theme2], db)

      expect(result).to eq([{ db: db, theme: theme1 }, { db: db, theme: theme2 }])
    end

    it "returns empty array when no themes provided" do
      result = wrap_themes_with_db([], "default")

      expect(result).to eq([])
    end
  end

  describe "#theme_identifier" do
    it "returns formatted theme identifier" do
      theme = Fabricate(:theme, name: "Test Theme")

      result = theme_identifier(theme)

      expect(result).to include("Test Theme")
      expect(result).to include(theme.id.to_s)
    end
  end

  describe "#map_translation_keys" do
    it "returns mapped keys for headline" do
      result = map_translation_keys("search_banner.headline")

      expect(result).to eq(
        %w[js.welcome_banner.header.anonymous_members js.welcome_banner.header.logged_in_members],
      )
    end

    it "returns mapped keys for subhead" do
      result = map_translation_keys("search_banner.subhead")

      expect(result).to eq(
        %w[
          js.welcome_banner.subheader.anonymous_members
          js.welcome_banner.subheader.logged_in_members
        ],
      )
    end

    it "returns empty array for unknown translation key" do
      result = map_translation_keys("unknown.key")

      expect(result).to eq([])
    end
  end

  describe "SETTINGS_MAPPING" do
    it "maps show_on setting correctly" do
      expect(SETTINGS_MAPPING["show_on"][:site_setting]).to eq("welcome_banner_page_visibility")
      expect(SETTINGS_MAPPING["show_on"][:value_mapping]["top_menu"]).to eq("top_menu_pages")
      expect(SETTINGS_MAPPING["show_on"][:value_mapping]["all"]).to eq("all_pages")
    end

    it "maps plugin_outlet setting correctly" do
      expect(SETTINGS_MAPPING["plugin_outlet"][:site_setting]).to eq("welcome_banner_location")
      expect(SETTINGS_MAPPING["plugin_outlet"][:value_mapping]["above-main-container"]).to eq(
        "above_topic_content",
      )
      expect(SETTINGS_MAPPING["plugin_outlet"][:value_mapping]["below-site-header"]).to eq(
        "below_site_header",
      )
    end

    it "maps background_image_light setting correctly" do
      expect(SETTINGS_MAPPING["background_image_light"][:site_setting]).to eq(
        "welcome_banner_image",
      )
      expect(SETTINGS_MAPPING["background_image_light"][:value_mapping]).to be_nil
    end
  end

  describe "#exclude_theme_component" do
    fab!(:parent_theme, :theme)
    fab!(:child_theme) { Fabricate(:theme, component: true) }

    it "excludes theme from parent themes when relations exist" do
      ChildTheme.create!(parent_theme: parent_theme, child_theme: child_theme)

      expect { exclude_theme_component(child_theme) }.to output(/Excluding.*from/).to_stdout
    end

    it "handles theme with no parent relations" do
      orphan_theme = Fabricate(:theme, component: true)

      expect { exclude_theme_component(orphan_theme) }.to output(
        /is not included in any of your themes/,
      ).to_stdout
    end
  end

  describe "#disable_theme_component" do
    it "disables an enabled theme" do
      theme = Fabricate(:theme, enabled: true)

      expect { disable_theme_component(theme) }.to output(/Disabled/).to_stdout
      expect(theme.reload.enabled).to eq(false)
    end

    it "skips disabling an already disabled theme" do
      theme = Fabricate(:theme, enabled: false)

      expect { disable_theme_component(theme) }.to output(/already disabled/).to_stdout
      expect(theme.reload.enabled).to eq(false)
    end
  end

  describe "#enable_welcome_banner" do
    fab!(:parent_theme, :theme)
    fab!(:child_theme) { Fabricate(:theme, component: true, enabled: true) }

    before { ChildTheme.create!(parent_theme: parent_theme, child_theme: child_theme) }

    it "enables welcome banner when theme is enabled and setting is false" do
      ThemeSiteSetting.create!(
        theme: parent_theme,
        name: "enable_welcome_banner",
        data_type: 5,
        value: "f",
      )

      expect { enable_welcome_banner(child_theme) }.to output(/enabled/).to_stdout
      expect(
        ThemeSiteSetting.find_by(theme: parent_theme, name: "enable_welcome_banner").value,
      ).to eq("t")
    end

    it "does nothing when theme is disabled" do
      disabled_theme = Fabricate(:theme, component: true, enabled: false)

      result = enable_welcome_banner(disabled_theme)

      expect(result).to be_nil
    end

    it "skips when theme has no parent relations" do
      orphan_theme = Fabricate(:theme, component: true, enabled: true)

      result = enable_welcome_banner(orphan_theme)

      expect(result).to be_nil
    end
  end
end
