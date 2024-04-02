# frozen_string_literal: true

RSpec.describe Admin::PluginsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#index" do
    context "while logged in as an admin" do
      before { sign_in(admin) }

      it "returns plugins" do
        get "/admin/plugins.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.has_key?("plugins")).to eq(true)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "returns plugins" do
        get "/admin/plugins.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.has_key?("plugins")).to eq(true)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/plugins.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#show" do
    before do
      spoiler_alert =
        Plugin::Instance.parse_from_source(
          File.join(Rails.root, "plugins", "spoiler-alert", "plugin.rb"),
        )
      poll =
        Plugin::Instance.parse_from_source(File.join(Rails.root, "plugins", "poll", "plugin.rb"))

      Discourse.stubs(:plugins_by_name).returns(
        { "discourse-spoiler-alert" => spoiler_alert, "poll" => poll },
      )
    end

    context "while logged in as an admin" do
      before { sign_in(admin) }

      it "returns a plugin" do
        get "/admin/plugins/poll.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["name"]).to eq("poll")
      end

      it "returns a plugin with the discourse- prefix if the prefixless version is queried" do
        get "/admin/plugins/spoiler-alert.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["name"]).to eq("spoiler-alert")
      end

      it "404s if the plugin is not found" do
        get "/admin/plugins/casino.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end

      it "404s if the plugin is not visible" do
        poll = Discourse.plugins_by_name["poll"]
        poll.stubs(:visible?).returns(false)

        get "/admin/plugins/poll.json"
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "returns plugins" do
        get "/admin/plugins/poll.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["name"]).to eq("poll")
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/plugins/poll.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end
end
