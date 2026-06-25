# frozen_string_literal: true

describe Admin::Config::AboutController do
  fab!(:admin)

  before do
    sign_in(admin)
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "ja|pt_BR"
  end

  describe "#localizations" do
    it "returns localizations for the requested locale" do
      SiteSettingLocalization.create!(setting_name: "title", locale: "ja", value: "日本語タイトル")
      SiteSettingLocalization.create!(
        setting_name: "site_description",
        locale: "pt_BR",
        value: "Descrição",
      )

      get "/admin/config/about/localizations.json", params: { locale: "ja" }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        "locale" => "ja",
        "localizations" => {
          "title" => {
            "value" => "日本語タイトル",
            "cooked" => nil,
          },
        },
      )
    end

    it "does not return blank localizations" do
      localization =
        SiteSettingLocalization.create!(setting_name: "title", locale: "ja", value: "日本語タイトル")
      localization.update_column(:value, "")

      get "/admin/config/about/localizations.json", params: { locale: "ja" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["localizations"]).to be_empty
    end

    it "normalizes hyphenated locale names" do
      get "/admin/config/about/localizations.json", params: { locale: "pt-BR" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["locale"]).to eq("pt_BR")
    end

    it "rejects the site default locale" do
      SiteSetting.default_locale = "en"

      get "/admin/config/about/localizations.json", params: { locale: "en" }

      expect(response.status).to eq(400)
    end

    it "rejects requests when content localization is disabled" do
      SiteSetting.content_localization_enabled = false

      get "/admin/config/about/localizations.json", params: { locale: "ja" }

      expect(response.status).to eq(403)
    end
  end

  describe "#update_localizations" do
    it "saves localized about settings and logs the change" do
      put "/admin/config/about/localizations.json",
          params: {
            locale: "ja",
            general_settings: {
              name: "日本語タイトル",
              summary: "日本語の説明",
              extended_description: "日本語の **詳細** 説明",
              about_banner_image: "/ignored.png",
            },
            contact_information: {
              community_owner: "日本語の所有者",
              contact_email: "ignored@example.com",
            },
            your_organization: {
              company_name: "日本語会社",
              company_url: "https://example.com/ja",
              governing_law: "日本法",
              city_for_disputes: "東京",
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("localizations", "title", "value")).to eq("日本語タイトル")
      expect(
        response.parsed_body.dig("localizations", "extended_site_description", "cooked"),
      ).to include("<strong>詳細</strong>")

      expect(response.parsed_body["localizations"].keys).to contain_exactly(
        "extended_site_description",
        "site_description",
        "title",
      )

      staff_action_log = UserHistory.where(action: UserHistory.actions[:custom_staff]).last

      aggregate_failures do
        expect(staff_action_log.custom_type).to eq("update_site_setting_localizations")
        expect(staff_action_log.details).to include("locale: ja")
        expect(staff_action_log.details).to include(
          "setting_names: extended_site_description|site_description|title",
        )
      end
    end

    it "removes a localization when the value is blank" do
      SiteSettingLocalization.create!(
        setting_name: "site_description",
        locale: "ja",
        value: "日本語の説明",
      )

      put "/admin/config/about/localizations.json",
          params: {
            locale: "ja",
            general_settings: {
              summary: "",
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["localizations"]).to be_empty
    end

    it "rejects unsupported locales" do
      put "/admin/config/about/localizations.json",
          params: {
            locale: "de",
            general_settings: {
              name: "Deutsch",
            },
          }

      expect(response.status).to eq(400)
    end

    it "rejects updates when content localization is disabled" do
      SiteSetting.content_localization_enabled = false

      put "/admin/config/about/localizations.json",
          params: {
            locale: "ja",
            general_settings: {
              name: "日本語タイトル",
            },
          }

      expect(response.status).to eq(403)
    end
  end
end
