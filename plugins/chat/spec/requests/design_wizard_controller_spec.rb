# frozen_string_literal: true

RSpec.describe Admin::Config::DesignWizardController do
  fab!(:admin)
  fab!(:general_category, :category)
  fab!(:general_channel) do
    Fabricate(:category_channel, chatable: general_category, name: "General")
  end
  fab!(:other_channel) { Fabricate(:category_channel, name: "General") }

  before do
    SiteSetting.concord_in_wizard = true
    SiteSetting.chat_enabled = true
    SiteSetting.enable_public_channels = true
    SiteSetting.general_category_id = general_category.id
  end

  describe "#index" do
    before { sign_in(admin) }

    it "offers General defaults and the current channel settings for a forum homepage" do
      SiteSetting.default_homepage = "categories"
      SiteSetting.chat_homepage_channel = other_channel.id
      get "/admin/config/design-wizard.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["additional_homepages"]).to eq(
        [
          {
            "id" => "chat",
            "name" => I18n.t("chat.design_wizard_homepage_name"),
            "description" =>
              I18n.t("chat.design_wizard_homepage_description", channel: general_channel.title),
            "icon" => "comments",
            "illustration" => "conversation",
            "path" => general_channel.relative_url,
            "settings" => {
              "chat_homepage_channel" => general_channel.id.to_s,
            },
          },
        ],
      )
      expect(response.parsed_body["homepage_settings"]).to eq(
        "chat_homepage_channel" => other_channel.id.to_s,
      )
    end

    it "returns the configured channel settings for a Chat homepage" do
      SiteSetting.default_homepage = "chat"
      SiteSetting.chat_homepage_channel = other_channel.id

      get "/admin/config/design-wizard.json"

      expect(response.parsed_body["homepage_settings"]).to eq(
        "chat_homepage_channel" => other_channel.id.to_s,
      )
    end

    it "omits the subfolder from the homepage path" do
      set_subfolder "/forum"

      get "/admin/config/design-wizard.json"

      expect(response.parsed_body["additional_homepages"].sole["path"]).to eq(
        "/chat/c/#{general_channel.slug}/#{general_channel.id}",
      )
    end

    it "does not substitute another channel named General when the General category has no channel" do
      general_channel.destroy!

      get "/admin/config/design-wizard.json"

      expect(response.parsed_body["additional_homepages"]).to eq([])
    end

    it "hides chat when the wizard setting is disabled" do
      SiteSetting.concord_in_wizard = false

      get "/admin/config/design-wizard.json"

      expect(response.parsed_body["additional_homepages"]).to eq([])
    end

    it "hides chat when public channels are disabled" do
      SiteSetting.enable_public_channels = false

      get "/admin/config/design-wizard.json"

      expect(response.parsed_body["additional_homepages"]).to eq([])
    end

    it "hides chat when the General category is private" do
      general_category.update!(read_restricted: true)

      get "/admin/config/design-wizard.json"

      expect(response.parsed_body["additional_homepages"]).to eq([])
    end

    it "hides chat when the General channel is archived" do
      general_channel.update!(status: :archived)

      get "/admin/config/design-wizard.json"

      expect(response.parsed_body["additional_homepages"]).to eq([])
    end

    it "hides chat when chat is disabled" do
      SiteSetting.chat_enabled = false

      get "/admin/config/design-wizard.json"

      expect(response.parsed_body["additional_homepages"]).to eq([])
    end
  end

  describe "#update" do
    let(:params) { { theme_id: Theme::CORE_THEMES["foundation"], homepage: "chat" } }

    before { sign_in(admin) }

    it "selects the General channel regardless of a supplied channel ID and keeps Foundation" do
      SiteSetting.chat_homepage_channel = other_channel.id

      put "/admin/config/design-wizard.json",
          params: params.merge(chat_homepage_channel: other_channel.id)

      expect(response.status).to eq(200)
      expect(SiteSetting.default_homepage).to eq("chat")
      expect(SiteSetting.chat_homepage_channel).to eq(general_channel.id.to_s)
      expect(SiteSetting.default_theme_id).to eq(Theme::CORE_THEMES["foundation"])
    end

    it "preserves the configured channel when choosing a forum homepage" do
      SiteSetting.chat_homepage_channel = other_channel.id

      put "/admin/config/design-wizard.json", params: params.merge(homepage: "categories")

      expect(response.status).to eq(200)
      expect(SiteSetting.default_homepage).to eq("categories")
      expect(SiteSetting.chat_homepage_channel).to eq(other_channel.id.to_s)
    end

    it "preserves the current Chat channel when saving the next wizard step" do
      SiteSetting.default_homepage = "chat"
      SiteSetting.chat_homepage_channel = other_channel.id

      put "/admin/config/design-wizard.json", params: params.merge(base_font: "lato")

      expect(response.status).to eq(200)
      expect(SiteSetting.chat_homepage_channel).to eq(other_channel.id.to_s)
      expect(SiteSetting.base_font).to eq("lato")
    end

    it "selects General when explicitly requested while Chat is already the homepage" do
      SiteSetting.default_homepage = "chat"
      SiteSetting.chat_homepage_channel = other_channel.id

      put "/admin/config/design-wizard.json",
          params:
            params.merge(homepage_settings: { chat_homepage_channel: general_channel.id.to_s })

      expect(response.status).to eq(200)
      expect(SiteSetting.chat_homepage_channel).to eq(general_channel.id.to_s)
    end

    %w[chat categories].each do |original_homepage|
      it "restores the original #{original_homepage} homepage and channel settings after a preview" do
        SiteSetting.default_homepage = original_homepage
        SiteSetting.chat_homepage_channel = other_channel.id

        get "/admin/config/design-wizard.json"
        snapshot = response.parsed_body.slice("homepage", "homepage_settings")

        put "/admin/config/design-wizard.json",
            params:
              params.merge(homepage_settings: { chat_homepage_channel: general_channel.id.to_s })
        expect(response.status).to eq(200)
        expect(SiteSetting.chat_homepage_channel).to eq(general_channel.id.to_s)

        put "/admin/config/design-wizard.json",
            params: snapshot.merge("theme_id" => Theme::CORE_THEMES["foundation"])

        expect(response.status).to eq(200)
        expect(SiteSetting.default_homepage).to eq(original_homepage)
        expect(SiteSetting.chat_homepage_channel).to eq(other_channel.id.to_s)
      end
    end

    it "rejects settings that are not registered homepage settings" do
      put "/admin/config/design-wizard.json",
          params: params.merge(homepage_settings: { title: "Unexpected title" })

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "rejects an unavailable channel without changing homepage settings" do
      SiteSetting.chat_homepage_channel = other_channel.id

      expect do
        put "/admin/config/design-wizard.json",
            params: params.merge(homepage_settings: { chat_homepage_channel: "999999" })
      end.not_to change { [SiteSetting.default_homepage, SiteSetting.chat_homepage_channel] }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "rejects channel overrides when the wizard setting is disabled" do
      SiteSetting.concord_in_wizard = false

      put "/admin/config/design-wizard.json",
          params:
            params.merge(
              homepage: "categories",
              homepage_settings: {
                chat_homepage_channel: general_channel.id.to_s,
              },
            )

      expect(response.status).to eq(400)
    end

    shared_examples "an unavailable chat homepage" do
      it "rejects the selection without updating homepage settings" do
        expect do put "/admin/config/design-wizard.json", params: end.not_to change {
          [SiteSetting.default_homepage, SiteSetting.chat_homepage_channel]
        }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end
    end

    context "when the wizard setting is disabled" do
      before { SiteSetting.concord_in_wizard = false }

      include_examples "an unavailable chat homepage"
    end

    context "when public channels are disabled" do
      before { SiteSetting.enable_public_channels = false }

      include_examples "an unavailable chat homepage"
    end

    context "when chat is disabled" do
      before { SiteSetting.chat_enabled = false }

      include_examples "an unavailable chat homepage"
    end

    context "when the General category is private" do
      before { general_category.update!(read_restricted: true) }

      include_examples "an unavailable chat homepage"
    end

    context "when the General channel is archived" do
      before { general_channel.update!(status: :archived) }

      include_examples "an unavailable chat homepage"
    end

    context "when the General category has no channel" do
      before { general_channel.destroy! }

      include_examples "an unavailable chat homepage"
    end
  end
end
