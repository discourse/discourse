# frozen_string_literal: true

RSpec.describe "tasks/migrate_discourse_gifs_to_core" do
  before do
    Rake::Task.clear
    silence_warnings { Discourse::Application.load_tasks }
  end

  # Mirrors the real discourse-gifs settings.yml so theme.settings resolves the
  # same defaults the migration reads in production (e.g. api_provider: giphy,
  # giphy_content_rating: r).
  SETTINGS_YAML = <<~YAML
    api_provider:
      default: "giphy"
      type: "enum"
      choices: [giphy, tenor, klipy]
    giphy_api_key:
      type: string
      default: ""
    giphy_file_format:
      type: enum
      default: webp
      choices: [webp, gif]
    giphy_content_rating:
      type: enum
      default: r
      choices: [g, pg, pg-13, r]
    giphy_locale:
      type: enum
      default: en
      choices:
        [
          ar, bn, cs, da, de, en, es, fa, fi, fr, hi, hu, id, it, iw, ja, ko,
          ms, nl, no, pl, pt, ro, ru, sv, th, tl, tr, uk, vi, zh-CN, zh-TW,
        ]
    limit_infinite_search_results:
      type: bool
      default: false
    max_results_limit:
      type: integer
      min: 24
      default: 240
    tenor_api_key:
      type: string
      default: ""
    tenor_file_detail:
      type: enum
      default: mediumgif
      choices: [gif, mediumgif, tinygif, nanogif]
    tenor_content_filter:
      type: "enum"
      default: high
      choices: [high, medium, low, "off"]
    tenor_country:
      type: string
      default: "US"
    tenor_locale:
      type: string
      default: "en_US"
    klipy_api_key:
      type: string
      default: ""
    klipy_file_detail:
      type: enum
      default: webp
      choices: [webp, gif]
    klipy_content_filter:
      type: "enum"
      default: high
      choices: [high, medium, low, "off"]
    klipy_country:
      type: string
      default: "US"
    klipy_locale:
      type: string
      default: "en_US"
  YAML

  fab!(:remote_theme) do
    RemoteTheme.create!(remote_url: "https://github.com/discourse/discourse-gifs")
  end
  fab!(:component) do
    Fabricate(:theme, component: true, remote_theme: remote_theme).tap do |theme|
      theme.set_field(target: :settings, name: "yaml", value: SETTINGS_YAML)
      theme.save!
    end
  end

  def add_overrides(theme, overrides)
    overrides.each { |name, value| theme.update_setting(name, value) }
    theme.save!
    theme.reload
  end

  def run_migration(theme, enable_gifs: false)
    expect {
      DiscourseGifsMigration.migrate_component(theme, enable_gifs: enable_gifs)
    }.to output.to_stdout
  end

  describe ".find_component_in_db" do
    it "returns the component when a single discourse-gifs install exists" do
      result = nil

      expect { result = DiscourseGifsMigration.find_component_in_db("default") }.to output(
        /✓ Found/,
      ).to_stdout
      expect(result).to eq(component)
    end

    it "matches the component when the remote_url ends in .git" do
      remote_theme.update!(remote_url: "https://github.com/discourse/discourse-gifs.git")

      result = nil
      expect { result = DiscourseGifsMigration.find_component_in_db("default") }.to output(
        /✓ Found/,
      ).to_stdout
      expect(result).to eq(component)
    end

    it "returns nil and warns when more than one install exists" do
      duplicate_remote =
        RemoteTheme.create!(remote_url: "https://github.com/discourse/discourse-gifs.git")
      Fabricate(:theme, component: true, remote_theme: duplicate_remote)

      result = nil
      expect { result = DiscourseGifsMigration.find_component_in_db("default") }.to output(
        /Multiple \(2\) discourse-gifs components found/,
      ).to_stdout
      expect(result).to be_nil
    end

    it "returns nil when no discourse-gifs component is installed" do
      component.destroy

      result = nil
      expect { result = DiscourseGifsMigration.find_component_in_db("default") }.to output(
        /Not found/,
      ).to_stdout
      expect(result).to be_nil
    end
  end

  describe ".migrate_component" do
    context "when the TC was configured for Giphy" do
      it "maps Giphy file format directly into klipy_file_detail" do
        add_overrides(component, api_provider: "giphy", giphy_file_format: "gif")

        run_migration(component)

        expect(SiteSetting.klipy_file_detail).to eq("gif")
      end

      it "maps every Giphy content rating to the agreed Klipy content filter",
         :aggregate_failures do
        rating_mappings = { "g" => "high", "pg" => "medium", "pg-13" => "low", "r" => "low" }

        rating_mappings.each do |giphy_rating, expected_filter|
          component.theme_settings.destroy_all
          add_overrides(component, api_provider: "giphy", giphy_content_rating: giphy_rating)

          run_migration(component)

          expect(SiteSetting.klipy_content_filter).to eq(expected_filter),
          "expected giphy '#{giphy_rating}' to map to '#{expected_filter}', got '#{SiteSetting.klipy_content_filter}'"
        end
      end

      it "translates the Giphy language code to a Klipy xx_YY locale", :aggregate_failures do
        {
          "fr" => "fr_FR",
          "ja" => "ja_JP",
          "zh-CN" => "zh_CN",
          "iw" => "he_IL",
        }.each do |giphy_locale, expected|
          component.theme_settings.destroy_all
          add_overrides(component, api_provider: "giphy", giphy_locale: giphy_locale)

          run_migration(component)

          expect(SiteSetting.klipy_locale).to eq(expected),
          "expected giphy '#{giphy_locale}' to map to '#{expected}', got '#{SiteSetting.klipy_locale}'"
        end
      end

      it "does not migrate the Giphy API key into klipy_api_key" do
        add_overrides(component, api_provider: "giphy", giphy_api_key: "old-giphy-key")
        original_api_key = SiteSetting.klipy_api_key

        run_migration(component)

        expect(SiteSetting.klipy_api_key).to eq(original_api_key)
      end
    end

    context "when the TC was configured for Tenor" do
      it "maps every Tenor file detail to the matching Klipy file detail", :aggregate_failures do
        detail_mappings = {
          "mediumgif" => "webp",
          "tinygif" => "webp",
          "nanogif" => "webp",
          "gif" => "gif",
        }

        detail_mappings.each do |tenor_detail, expected_klipy|
          component.theme_settings.destroy_all
          add_overrides(component, api_provider: "tenor", tenor_file_detail: tenor_detail)

          run_migration(component)

          expect(SiteSetting.klipy_file_detail).to eq(expected_klipy),
          "expected tenor '#{tenor_detail}' to map to '#{expected_klipy}', got '#{SiteSetting.klipy_file_detail}'"
        end
      end

      it "passes Tenor content filter, country and locale (already xx_YY) through",
         :aggregate_failures do
        add_overrides(
          component,
          api_provider: "tenor",
          tenor_content_filter: "medium",
          tenor_country: "GB",
          tenor_locale: "en_GB",
        )

        run_migration(component)

        expect(SiteSetting.klipy_content_filter).to eq("medium")
        expect(SiteSetting.klipy_country).to eq("GB")
        expect(SiteSetting.klipy_locale).to eq("en_GB")
      end

      it "does not migrate the Tenor API key into klipy_api_key" do
        add_overrides(component, api_provider: "tenor", tenor_api_key: "old-tenor-key")
        original_api_key = SiteSetting.klipy_api_key

        run_migration(component)

        expect(SiteSetting.klipy_api_key).to eq(original_api_key)
      end
    end

    context "when the TC was already configured for Klipy" do
      it "copies every Klipy setting through, including the API key", :aggregate_failures do
        add_overrides(
          component,
          api_provider: "klipy",
          klipy_api_key: "existing-klipy-key",
          klipy_file_detail: "gif",
          klipy_content_filter: "low",
          klipy_country: "DE",
          klipy_locale: "de_DE",
        )

        run_migration(component)

        expect(SiteSetting.klipy_api_key).to eq("existing-klipy-key")
        expect(SiteSetting.klipy_file_detail).to eq("gif")
        expect(SiteSetting.klipy_content_filter).to eq("low")
        expect(SiteSetting.klipy_country).to eq("DE")
        expect(SiteSetting.klipy_locale).to eq("de_DE")
      end
    end

    context "with shared settings that apply regardless of provider" do
      it "migrates limit_infinite_search_results" do
        add_overrides(component, api_provider: "tenor", limit_infinite_search_results: true)

        run_migration(component)

        expect(SiteSetting.klipy_limit_infinite_search_results).to eq(true)
      end

      it "migrates max_results_limit" do
        add_overrides(component, api_provider: "giphy", max_results_limit: 96)

        run_migration(component)

        expect(SiteSetting.klipy_max_results_limit).to eq(96)
      end
    end

    context "when the TC uses its default (untouched) settings" do
      it "migrates effective defaults, e.g. giphy's default 'r' rating to klipy 'low'" do
        # No ThemeSetting rows exist, so this only passes if defaults are read.
        run_migration(component)

        expect(SiteSetting.klipy_content_filter).to eq("low")
      end
    end

    context "when api_provider is not set in theme settings" do
      it "defaults to giphy and applies giphy mappings" do
        add_overrides(component, giphy_content_rating: "pg")

        run_migration(component)

        expect(SiteSetting.klipy_content_filter).to eq("medium")
      end
    end

    context "with disabled_image_download_domains" do
      it "adds Klipy media hosts when a gif-provider host was blocked, keeping others" do
        SiteSetting.disabled_image_download_domains = "example.com|media.giphy.com"

        run_migration(component)

        expect(SiteSetting.disabled_image_download_domains.split("|")).to include(
          "example.com",
          "media.giphy.com",
          "static.klipy.com",
          "static1.klipy.com",
          "static2.klipy.com",
        )
      end

      it "does not touch the setting when no gif-provider host is blocked" do
        SiteSetting.disabled_image_download_domains = "example.com"

        run_migration(component)

        expect(SiteSetting.disabled_image_download_domains).to eq("example.com")
      end

      it "does not duplicate Klipy hosts on re-run" do
        SiteSetting.disabled_image_download_domains = "media.giphy.com"

        run_migration(component)
        run_migration(component)

        hosts = SiteSetting.disabled_image_download_domains.split("|")
        expect(hosts.count("static.klipy.com")).to eq(1)
      end
    end

    context "with theme translation overrides" do
      def add_translation_override(theme, key, value, locale: "en")
        ThemeTranslationOverride.create!(theme:, locale:, translation_key: key, value:)
      end

      it "migrates customised strings (per locale) to the matching core site text",
         :aggregate_failures do
        add_translation_override(component, "gif.composer_title", "Add a GIF")
        add_translation_override(component, "gif.modal_title", "Chercher des GIFs", locale: "fr")

        run_migration(component)

        expect(
          TranslationOverride.find_by(
            locale: "en",
            translation_key: "js.gifs.composer_title",
          )&.value,
        ).to eq("Add a GIF")
        expect(
          TranslationOverride.find_by(locale: "fr", translation_key: "js.gifs.modal_title")&.value,
        ).to eq("Chercher des GIFs")
      end

      it "skips overrides of keys with no core equivalent" do
        add_translation_override(component, "gif.query", "Keyword")

        run_migration(component)

        expect(TranslationOverride.where("translation_key LIKE 'js.gifs.%'")).to be_empty
      end
    end

    context "with the enable_gifs keyword" do
      it "leaves enable_gifs untouched by default" do
        SiteSetting.enable_gifs = false
        add_overrides(component, api_provider: "klipy", klipy_api_key: "key")

        run_migration(component, enable_gifs: false)

        expect(SiteSetting.enable_gifs).to eq(false)
      end

      it "flips enable_gifs to true when enable_gifs: true is passed" do
        SiteSetting.enable_gifs = false
        add_overrides(component, api_provider: "klipy", klipy_api_key: "key")

        run_migration(component, enable_gifs: true)

        expect(SiteSetting.enable_gifs).to eq(true)
      end
    end

    it "records migrated settings in the staff action log with an audit reason" do
      add_overrides(component, api_provider: "klipy", klipy_locale: "de_DE")

      run_migration(component)

      log =
        UserHistory.where(
          action: UserHistory.actions[:change_site_setting],
          subject: "klipy_locale",
        ).last
      expect(log).to be_present
      expect(log.details).to include("Migrated from discourse-gifs theme component")
    end
  end
end
