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

  describe "#update" do
    it "edits and reverts a theme text without creating a site override" do
      put path, params: { site_text: { locale: "ja", value: "Custom intro" } }
      expect(response.status).to eq(200)
      expect(response.parsed_body["site_text"]).to include(
        "value" => "Custom intro",
        "can_revert" => true,
        "new_default" => "リソースを見る",
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
