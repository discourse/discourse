# frozen_string_literal: true

RSpec.describe Admin::Config::DesignWizardController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#index" do
    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "returns the core themes with their palette pairs" do
        ThemeField.create!(
          theme_id: Theme::CORE_THEMES["horizon"],
          name: "en",
          type_id: ThemeField.types[:yaml],
          target_id: Theme.targets[:translations],
          value: <<~YAML,
            en:
              theme_metadata:
                description: "A simple, beautiful theme"
          YAML
        )

        get "/admin/config/design-wizard.json"

        expect(response.status).to eq(200)

        themes = response.parsed_body["themes"]
        expect(themes.map { |theme| theme["id"] }).to contain_exactly(
          Theme::CORE_THEMES["foundation"],
          Theme::CORE_THEMES["horizon"],
        )

        horizon = themes.find { |theme| theme["id"] == Theme::CORE_THEMES["horizon"] }
        expect(horizon["description"]).to eq("A simple, beautiful theme")
        expect(horizon["palette_pairs"].map { |pair| pair["key"] }).to include(
          "horizon",
          "royal",
          "clover",
          "lily",
          "violet",
          "marigold",
        )
        horizon_pair = horizon["palette_pairs"].find { |pair| pair["key"] == "horizon" }
        expect(horizon_pair["light"]["colors"]).to include("primary", "secondary", "tertiary")
        expect(horizon_pair["dark"]["name"]).to eq("Horizon Dark")

        foundation = themes.find { |theme| theme["id"] == Theme::CORE_THEMES["foundation"] }
        expect(foundation["palette_pairs"].map { |pair| pair["key"] }).to eq(
          %w[default wcag solarized dracula],
        )
        dracula = foundation["palette_pairs"].find { |pair| pair["key"] == "dracula" }
        expect(dracula["dark_only"]).to eq(true)
        expect(dracula["light"]).to be_nil
      end

      context "with a theme screenshot" do
        fab!(:upload, :image_upload)

        before do
          horizon = Theme.horizon_theme
          horizon.set_field(
            target: :common,
            name: "screenshot_light",
            type: :theme_screenshot_upload_var,
            upload_id: upload.id,
          )
          horizon.save!
        end

        def serialized_horizon
          get "/admin/config/design-wizard.json"
          response.parsed_body["themes"].find do |theme|
            theme["id"] == Theme::CORE_THEMES["horizon"]
          end
        end

        it "serves the full-size screenshot and schedules a resize when none exists yet" do
          expect_enqueued_with(
            job: :generate_theme_screenshot_thumbnails,
            args: {
              theme_id: Theme::CORE_THEMES["horizon"],
            },
          ) { expect(serialized_horizon["screenshot_light_url"]).to eq(upload.url) }
        end

        it "only schedules the resize once while it is outstanding" do
          serialized_horizon

          expect { serialized_horizon }.not_to change {
            Jobs::GenerateThemeScreenshotThumbnails.jobs.size
          }
        end

        it "serves the resized screenshot once it has been generated" do
          Jobs::GenerateThemeScreenshotThumbnails.new.execute(
            theme_id: Theme::CORE_THEMES["horizon"],
          )

          url = serialized_horizon["screenshot_light_url"]

          expect(url).not_to eq(upload.url)
          expect(OptimizedImage.find_by(upload_id: upload.id)).to have_attributes(
            url:,
            width: ThemeScreenshotThumbnails::WIDTH,
            height: ThemeScreenshotThumbnails::HEIGHT,
            extension: ".webp",
          )
        end
      end

      it "returns the current fonts and homepage" do
        SiteSetting.base_font = "lato"
        SiteSetting.heading_font = "merriweather"
        SiteSetting.default_homepage = "categories"

        get "/admin/config/design-wizard.json"

        expect(response.parsed_body["base_font"]).to eq("lato")
        expect(response.parsed_body["heading_font"]).to eq("merriweather")
        expect(response.parsed_body["homepage"]).to eq("categories")
      end

      it "does not include current_theme when the default theme is a core theme" do
        get "/admin/config/design-wizard.json"

        expect(response.parsed_body["current_theme"]).to be_nil
      end

      it "includes current_theme when the default theme is a custom theme" do
        theme = Fabricate(:theme)
        theme.set_default!

        get "/admin/config/design-wizard.json"

        expect(response.parsed_body["current_theme"]).to include(
          "id" => theme.id,
          "name" => theme.name,
        )
      end

      it "reports palettes as not user selectable when only a custom default theme's palettes are selectable" do
        theme = Fabricate(:theme)
        Fabricate(:color_scheme, theme_id: theme.id, user_selectable: true)
        theme.set_default!

        get "/admin/config/design-wizard.json"

        expect(response.parsed_body["palettes_user_selectable"]).to eq(false)
      end

      it "reports palettes as not user selectable when there are none to offer" do
        ColorScheme.where(theme_id: Theme::CORE_THEMES.values).destroy_all
        ColorScheme.where(via_wizard: true).destroy_all

        get "/admin/config/design-wizard.json"

        expect(response.parsed_body["palettes_user_selectable"]).to eq(false)
      end

      it "reports palettes as user selectable when horizon's palettes are selectable and the default theme is custom" do
        ColorScheme.where(theme_id: Theme::CORE_THEMES["horizon"]).update_all(user_selectable: true)
        theme = Fabricate(:theme)
        Fabricate(:color_scheme, theme_id: theme.id, user_selectable: false)
        theme.set_default!

        get "/admin/config/design-wizard.json"

        expect(response.parsed_body["palettes_user_selectable"]).to eq(true)
      end
    end

    it "is not accessible to moderators" do
      sign_in(moderator)

      get "/admin/config/design-wizard.json"

      expect(response.status).to eq(403)
    end

    it "is not accessible to regular users" do
      sign_in(user)

      get "/admin/config/design-wizard.json"

      expect(response.status).to eq(404)
    end

    it "is not accessible to anonymous users" do
      get "/admin/config/design-wizard.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#update" do
    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "applies the design choices" do
        horizon = Theme.horizon_theme
        light = ColorScheme.find_by(theme_id: horizon.id, name: "Royal")
        dark = ColorScheme.find_by(theme_id: horizon.id, name: "Royal Dark")

        put "/admin/config/design-wizard.json",
            params: {
              theme_id: horizon.id,
              light_palette_id: light.id,
              dark_palette_id: dark.id,
              palettes_user_selectable: true,
              base_font: "lato",
              heading_font: "merriweather",
              homepage: "categories",
              category_page_style: "categories_boxes",
              welcome_banner_location: "below_site_header",
            }

        expect(response.status).to eq(200)
        expect(SiteSetting.default_theme_id).to eq(horizon.id)
        expect(horizon.reload.color_scheme_id).to eq(light.id)
        expect(horizon.dark_color_scheme_id).to eq(dark.id)
        expect(SiteSetting.base_font).to eq("lato")
        expect(SiteSetting.heading_font).to eq("merriweather")
        expect(SiteSetting.default_homepage).to eq("categories")
        expect(SiteSetting.desktop_category_page_style).to eq("categories_boxes")
        expect(SiteSetting.welcome_banner_location).to eq("below_site_header")
        expect(light.reload.user_selectable).to eq(true)
      end

      it "applies the welcome banner and search choices to the chosen theme" do
        horizon = Theme.horizon_theme

        put "/admin/config/design-wizard.json",
            params: {
              theme_id: horizon.id,
              enable_welcome_banner: false,
              search_experience: "search_field",
            }

        expect(response.status).to eq(200)
        expect(SiteSetting.enable_welcome_banner(theme_id: horizon.id)).to eq(false)
        expect(SiteSetting.search_experience(theme_id: horizon.id)).to eq("search_field")
      end

      it "returns a 400 for an unsupported search experience" do
        put "/admin/config/design-wizard.json",
            params: {
              theme_id: Theme::CORE_THEMES["horizon"],
              search_experience: "not_an_experience",
            }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns a 400 with errors for an invalid contract" do
        put "/admin/config/design-wizard.json",
            params: {
              theme_id: Theme::CORE_THEMES["foundation"],
              base_font: "not_a_font",
            }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns a 422 when a palette is not available for the theme" do
        horizon_palette = ColorScheme.find_by(theme_id: Theme::CORE_THEMES["horizon"])

        put "/admin/config/design-wizard.json",
            params: {
              theme_id: Theme::CORE_THEMES["foundation"],
              light_palette_id: horizon_palette.id,
            }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns a 422 when the site settings cannot be updated" do
        SiteSetting.stubs(:shadowed_settings).returns(Set.new(%i[default_theme_id]))

        put "/admin/config/design-wizard.json", params: { theme_id: Theme::CORE_THEMES["horizon"] }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(
          [I18n.t("design_wizard.errors.site_settings_update_failed")],
        )
      end
    end

    it "is not accessible to moderators" do
      sign_in(moderator)

      put "/admin/config/design-wizard.json", params: { theme_id: Theme::CORE_THEMES["horizon"] }

      expect(response.status).to eq(403)
      expect(SiteSetting.default_theme_id).not_to eq(Theme::CORE_THEMES["horizon"])
    end

    it "is not accessible to anonymous users" do
      put "/admin/config/design-wizard.json", params: { theme_id: Theme::CORE_THEMES["foundation"] }

      expect(response.status).to eq(404)
    end
  end
end
