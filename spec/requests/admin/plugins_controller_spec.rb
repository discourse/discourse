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
      csp_extension =
        Plugin::Instance.parse_from_source(
          Rails.root.join("spec/fixtures/plugins/csp_extension/plugin.rb").to_s,
        )
      my_plugin =
        Plugin::Instance.parse_from_source(
          Rails.root.join("spec/fixtures/plugins/my_plugin/plugin.rb").to_s,
        )

      Discourse.stubs(:plugins_by_name).returns(
        { "csp_extension" => csp_extension, "discourse-plugin-name" => my_plugin },
      )
    end

    context "while logged in as an admin" do
      before { sign_in(admin) }

      it "returns a plugin" do
        get "/admin/plugins/csp_extension.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["name"]).to eq("csp_extension")
        expect(response.parsed_body["use_horizontal_settings_form"]).to eq(false)
      end

      it "returns the horizontal settings form flag when a plugin opts in" do
        Discourse.plugins_by_name["csp_extension"].use_horizontal_settings_form true

        get "/admin/plugins/csp_extension.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["use_horizontal_settings_form"]).to eq(true)
      end

      it "returns a plugin with the discourse- prefix if the prefixless version is queried" do
        get "/admin/plugins/plugin-name.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["name"]).to eq("plugin-name")
      end

      it "404s if the plugin is not found" do
        get "/admin/plugins/casino.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end

      it "404s if the plugin is not visible" do
        Discourse.plugins_by_name["csp_extension"].stubs(:visible?).returns(false)

        get "/admin/plugins/csp_extension.json"
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "returns plugins" do
        get "/admin/plugins/csp_extension.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["name"]).to eq("csp_extension")
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/plugins/csp_extension.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end
end
