# frozen_string_literal: true

RSpec.describe Admin::SiteTextsController do
  fab!(:admin)
  fab!(:theme) { Fabricate(:theme, component: true) }
  fab!(:other_theme) { Fabricate(:theme, component: true) }

  before do
    theme.set_field(
      target: :translations,
      name: "en",
      value: {
        en: {
          resource_intro: "Explore resources",
          greeting: "Hello %{name}",
        },
      }.deep_stringify_keys.to_yaml,
    )
    theme.set_field(
      target: :translations,
      name: "ja",
      value: { ja: { resource_intro: "リソースを見る" } }.deep_stringify_keys.to_yaml,
    )
    theme.save!
    other_theme.set_field(
      target: :translations,
      name: "en",
      value: { en: { resource_intro: "Other resources" } }.deep_stringify_keys.to_yaml,
    )
    other_theme.save!
    sign_in(admin)
  end

  let(:text_id) { "js.theme_translations.#{theme.id}.resource_intro" }
  let(:path) { "/admin/customize/site_texts/#{text_id}.json" }

  describe "#index" do
    it "lists the selected component's defaults before any overrides exist" do
      get "/admin/customize/site_texts.json", params: { theme_id: theme.id, locale: "en" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["site_texts"].map { |text| text["id"] }).to contain_exactly(
        text_id,
        "js.theme_translations.#{theme.id}.greeting",
      )
      expect(response.parsed_body["extras"]["themes"]).to include(
        "id" => theme.id,
        "name" => theme.name,
        "enabled" => true,
      )
    end

    it "searches theme texts and displays the selected language" do
      get "/admin/customize/site_texts.json",
          params: {
            theme_id: theme.id,
            q: "resource_intro",
            locale: "ja",
          }
      expect(response.parsed_body["site_texts"]).to contain_exactly(
        include("id" => text_id, "value" => "リソースを見る"),
      )
      get "/admin/customize/site_texts.json", params: { q: text_id, locale: "en" }
      expect(response.parsed_body["site_texts"]).to contain_exactly(include("id" => text_id))
    end

    it "filters overrides by the selected theme and locale" do
      ThemeTranslationOverride.create!(
        theme: theme,
        locale: "ja",
        translation_key: "resource_intro",
        value: "Custom intro",
      )
      get "/admin/customize/site_texts.json",
          params: {
            theme_id: theme.id,
            locale: "en",
            overridden: true,
          }
      expect(response.parsed_body["site_texts"]).to eq([])
      get "/admin/customize/site_texts.json",
          params: {
            theme_id: theme.id,
            locale: "ja",
            overridden: true,
          }
      expect(response.parsed_body["site_texts"]).to contain_exactly(
        include("id" => text_id, "value" => "Custom intro", "overridden" => true),
      )
    end

    it "treats locale-file translations as translated and fallback texts as untranslated" do
      get "/admin/customize/site_texts.json",
          params: {
            theme_id: theme.id,
            locale: "ja",
            untranslated: true,
          }
      expect(response.parsed_body["site_texts"].map { |text| text["id"] }).to eq(
        ["js.theme_translations.#{theme.id}.greeting"],
      )
    end

    it "paginates within the selected theme" do
      values = 55.times.to_h { |index| ["label_#{index}", "Resource #{index}"] }
      theme.set_field(target: :translations, name: "en", value: { "en" => values }.to_yaml)
      theme.save!
      get "/admin/customize/site_texts.json", params: { theme_id: theme.id, locale: "en" }
      first_page = response.parsed_body["site_texts"].map { |text| text["id"] }
      expect(first_page.size).to eq(50)
      expect(response.parsed_body["extras"]["has_more"]).to eq(true)
      get "/admin/customize/site_texts.json", params: { theme_id: theme.id, locale: "en", page: 1 }
      second_page = response.parsed_body["site_texts"].map { |text| text["id"] }
      expect(second_page.size).to eq(5)
      expect(first_page & second_page).to be_empty
      get "/admin/customize/site_texts.json", params: { theme_id: theme.id, locale: "en", page: 99 }
      expect(response.parsed_body["site_texts"]).to eq([])
    end

    it "can display a target-language value when searching by English text" do
      get "/admin/customize/site_texts.json",
          params: {
            theme_id: theme.id,
            q: "Explore resources",
            locale: "ja",
            only_selected_locale: true,
          }
      expect(response.parsed_body["site_texts"]).to contain_exactly(
        include("id" => text_id, "value" => "リソースを見る"),
      )
    end

    it "returns not found for a missing theme" do
      get "/admin/customize/site_texts.json", params: { theme_id: 999_999, locale: "en" }
      expect(response.status).to eq(404)
    end
  end

  describe "object-editor translations" do
    let(:object_key) { "resource_sections.getting_started.links.guidelines.label" }
    let(:object_text_id) { "js.theme_translations.#{theme.id}.#{object_key}" }

    before do
      theme.set_field(
        target: :settings,
        name: "yaml",
        value: File.read(file_from_fixtures("translatable_objects.yaml", "theme_settings")),
      )
      theme.save!
    end

    it "lists dynamic defaults, filters changed text, and dismisses the outdated warning" do
      get "/admin/customize/site_texts.json", params: { theme_id: theme.id, locale: "ja" }
      expect(response.parsed_body["site_texts"]).to include(
        include(
          "id" => object_text_id,
          "value" => "Community guidelines",
          "default_locale" => "en",
        ),
      )
      put "/admin/customize/site_texts/#{object_text_id}.json",
          params: {
            site_text: {
              locale: "ja",
              value: "ガイドライン",
            },
          }
      expect(response.status).to eq(200)
      objects = theme.settings[:resource_sections].value
      objects[0]["links"][0]["label"] = "Updated guidelines"
      theme.update_setting(:resource_sections, objects)
      get "/admin/customize/site_texts.json",
          params: {
            theme_id: theme.id,
            locale: "ja",
            outdated: true,
          }
      expect(response.parsed_body["site_texts"]).to contain_exactly(
        include(
          "id" => object_text_id,
          "status" => "outdated",
          "old_default" => "Community guidelines",
          "new_default" => "Updated guidelines",
        ),
      )
      put "/admin/customize/site_texts/#{object_text_id}/dismiss_outdated.json",
          params: {
            locale: "ja",
          }
      expect(response.status).to eq(200)
      get "/admin/customize/site_texts/#{object_text_id}.json", params: { locale: "ja" }
      expect(response.parsed_body["site_text"]).to include(
        "status" => "up_to_date",
        "value" => "ガイドライン",
      )
    end

    it "returns a detailed JSON validation error for the editor's extensionless save URL" do
      I18n.with_locale(:ja) { theme.update_translation(object_key, "Custom guidelines") }

      expect do
        put "/admin/customize/site_texts/#{object_text_id}",
            headers: {
              "Accept" => "*/*",
              "X-Requested-With" => "XMLHttpRequest",
            },
            params: {
              site_text: {
                locale: "ja",
                value: "%{unknown}",
              },
            }
      end.not_to change { UserHistory.count }

      expect(response.status).to eq(422)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body["errors"].join(" ")).to include("unknown")
      expect(
        theme.theme_translation_overrides.find_by!(locale: "ja", translation_key: object_key).value,
      ).to eq("Custom guidelines")
    end

    it "rejects invalid placeholders without changing the existing translation" do
      put "/admin/customize/site_texts/#{object_text_id}.json",
          params: {
            site_text: {
              locale: "ja",
              value: "%{unknown}",
            },
          }
      expect(response.status).to eq(422)
      expect(ThemeTranslationOverride.where(theme: theme, translation_key: object_key)).to be_empty
    end

    it "acknowledges a legacy baseline without changing its text or listing it as outdated" do
      I18n.with_locale(:ja) { theme.update_translation(object_key, "ガイドライン") }
      record = theme.theme_translation_overrides.find_by!(locale: "ja", translation_key: object_key)
      record.update_columns(original_translation: nil)
      get "/admin/customize/site_texts.json",
          params: {
            theme_id: theme.id,
            locale: "ja",
            outdated: true,
          }
      expect(response.parsed_body["site_texts"]).to be_empty
      put "/admin/customize/site_texts/#{object_text_id}/dismiss_outdated.json",
          params: {
            locale: "ja",
          }
      expect(response.status).to eq(200)
      expect(record.reload.status).to eq("up_to_date")
      expect(record.value).to eq("ガイドライン")
    end

    it "reports legacy invalid overrides separately from outdated overrides" do
      record =
        ThemeTranslationOverride.create!(
          theme: theme,
          translation_key: object_key,
          locale: "ja",
          value: "Guidelines",
        )
      record.update_columns(value: "%{unknown}")
      get "/admin/customize/site_texts.json",
          params: {
            theme_id: theme.id,
            locale: "ja",
            outdated: true,
          }
      expect(response.parsed_body["site_texts"]).to contain_exactly(
        include("id" => object_text_id, "status" => "invalid_interpolation_keys"),
      )
      put "/admin/customize/site_texts/#{object_text_id}/dismiss_outdated.json",
          params: {
            locale: "ja",
          }
      expect(response.status).to eq(422)
    end
  end

  describe "#update" do
    it "accepts English placeholders omitted by the selected locale's shipped text" do
      theme.set_field(target: :translations, name: "fr", value: "fr:\n  greeting: Bonjour\n")
      theme.save!

      put "/admin/themes/#{theme.id}.json",
          params: {
            theme: {
              locale: "fr",
              translations: {
                greeting: "Bonjour %{name}",
              },
            },
          }

      expect(response.status).to eq(200)
      record = theme.theme_translation_overrides.find_by!(locale: "fr", translation_key: "greeting")
      expect(record.value).to eq("Bonjour %{name}")
      expect(record.status).to eq("up_to_date")
    end

    it "accepts and edits runtime placeholders absent from shipped text without invalid warnings" do
      put path, params: { site_text: { locale: "en", value: "Explore %{name}" } }

      expect(response.status).to eq(200)
      expect(response.parsed_body["site_text"]).to include(
        "value" => "Explore %{name}",
        "status" => "up_to_date",
        "interpolation_keys" => nil,
      )

      put path, params: { site_text: { locale: "en", value: "Welcome %{name}" } }

      expect(response.status).to eq(200)
      record =
        theme.theme_translation_overrides.find_by!(locale: "en", translation_key: "resource_intro")
      expect(record.value).to eq("Welcome %{name}")
      expect(record.original_translation).to eq("Explore resources")
      expect(record.status).to eq("up_to_date")
    end

    it "rolls back all translation updates when a later key is invalid" do
      theme.set_field(
        target: :settings,
        name: "yaml",
        value: File.read(file_from_fixtures("translatable_objects.yaml", "theme_settings")),
      )
      theme.save!
      object_key = "resource_sections.getting_started.links.guidelines.label"
      I18n.with_locale(:fr) { theme.update_translation("resource_intro", "Existing intro") }
      theme.set_field(
        target: :translations,
        name: "en",
        value:
          "en:\n  resource_intro: Explore resources\n  second: Second\n  greeting: Hello %{name}\n",
      )
      theme.save!

      put "/admin/themes/#{theme.id}.json",
          params: {
            theme: {
              locale: "fr",
              translations: {
                :resource_intro => "Updated intro",
                :second => "Deuxième",
                object_key => "Bonjour %{unknown}",
              },
            },
          }

      expect(response.status).to eq(422)
      expect(theme.theme_translation_overrides.reload.pluck(:translation_key, :value)).to eq(
        [["resource_intro", "Existing intro"]],
      )
    end

    it "saves multiple translations with placeholders from the selected locale" do
      theme.set_field(
        target: :translations,
        name: "en",
        value: "en:\n  resource_intro: Explore resources\n  greeting: Welcome\n",
      )
      theme.set_field(
        target: :translations,
        name: "fr",
        value: "fr:\n  resource_intro: Ressources\n  greeting: Bonjour %{name}\n",
      )
      theme.save!

      put "/admin/themes/#{theme.id}.json",
          params: {
            theme: {
              locale: "fr",
              translations: {
                resource_intro: "Toutes les ressources",
                greeting: "Bienvenue %{name}",
              },
            },
          }

      expect(response.status).to eq(200)
      expect(
        theme.theme_translation_overrides.reload.pluck(:translation_key, :value),
      ).to contain_exactly(
        ["resource_intro", "Toutes les ressources"],
        ["greeting", "Bienvenue %{name}"],
      )
    end

    it "edits and reverts a theme text without creating a site override" do
      put path, params: { site_text: { locale: "ja", value: "Custom intro" } }
      expect(response.status).to eq(200)
      expect(response.parsed_body["site_text"]).to include(
        "value" => "Custom intro",
        "can_revert" => true,
        "new_default" => "Explore resources",
      )
      expect(
        ThemeTranslationOverride.find_by!(
          theme: theme,
          locale: "ja",
          translation_key: "resource_intro",
        ).value,
      ).to eq("Custom intro")
      expect(TranslationOverride.exists?(translation_key: text_id)).to eq(false)
      get path, params: { locale: "ja" }
      expect(response.parsed_body["site_text"]["value"]).to eq("Custom intro")
      delete path, params: { locale: "ja" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["site_text"]).to include(
        "value" => "リソースを見る",
        "can_revert" => false,
        "overridden" => false,
      )
      expect(ThemeTranslationOverride.where(theme: theme)).to be_empty
    end

    it "removes an override when saving the locale-file default" do
      ThemeTranslationOverride.create!(
        theme: theme,
        locale: "en",
        translation_key: "resource_intro",
        value: "Custom intro",
      )
      put path, params: { site_text: { locale: "en", value: "Explore resources" } }
      expect(response.status).to eq(200)
      expect(response.parsed_body["site_text"]).to include(
        "value" => "Explore resources",
        "can_revert" => false,
      )
      expect(ThemeTranslationOverride.where(theme: theme)).to be_empty
    end

    it "respects plugin restrictions on theme edits" do
      record =
        ThemeTranslationOverride.create!(
          theme: theme,
          locale: "ja",
          translation_key: "resource_intro",
          value: "Custom intro",
        )
      record.update_columns(original_translation: nil)
      plugin = Plugin::Instance.new
      modifier = proc { |allowed, _guardian, target| allowed && target.id != theme.id }
      plugin.register_modifier(:user_guardian_can_edit_theme, &modifier)

      put path, params: { site_text: { locale: "en", value: "Blocked" } }
      expect(response.status).to eq(403)

      delete path, params: { locale: "en" }
      expect(response.status).to eq(403)

      put "/admin/customize/site_texts/#{text_id}/dismiss_outdated.json", params: { locale: "ja" }
      expect(response.status).to eq(403)
      expect(record.reload.original_translation).to be_nil
      expect(record.value).to eq("Custom intro")
    ensure
      if plugin
        DiscoursePluginRegistry.unregister_modifier(
          plugin,
          :user_guardian_can_edit_theme,
          &modifier
        )
      end
    end

    it "rejects unknown keys and malformed values" do
      put "/admin/customize/site_texts/js.theme_translations.#{theme.id}.missing.json",
          params: {
            site_text: {
              locale: "en",
              value: "No",
            },
          }
      expect(response.status).to eq(404)
      put path, params: { site_text: { locale: "en", value: { bad: "value" } } }
      expect(response.status).to eq(400)
      expect(ThemeTranslationOverride.where(theme: theme)).to be_empty
    end

    it "requires an admin for reading and editing theme texts" do
      sign_in(Fabricate(:moderator))
      get "/admin/customize/site_texts.json", params: { theme_id: theme.id, locale: "en" }
      expect(response.status).to eq(404)
      get path, params: { locale: "en" }
      expect(response.status).to eq(404)
      put path, params: { site_text: { locale: "en", value: "No" } }
      expect(response.status).to eq(404)
      delete path, params: { locale: "en" }
      expect(response.status).to eq(404)
    end
  end
end
