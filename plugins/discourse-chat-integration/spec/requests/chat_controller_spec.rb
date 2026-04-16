# frozen_string_literal: true

require_relative "../dummy_provider"

RSpec.describe "Chat Controller", type: :request do
  let(:topic) { Fabricate(:post).topic }
  let(:admin) { Fabricate(:admin) }
  let(:category) { Fabricate(:category) }
  let(:category2) { Fabricate(:category) }
  let(:tag) { Fabricate(:tag) }
  let(:channel) { DiscourseChatIntegration::Channel.create(provider: "dummy") }

  include_context "with dummy provider"
  include_context "with validated dummy provider"

  before do
    SiteSetting.chat_integration_enabled = true
    SiteSetting.dummy_provider_enabled = true
  end

  shared_examples "admin constraints" do |action, route|
    context "when user is not signed in" do
      it "should raise the right error" do
        public_send(action, route)
        expect(response.status).to eq(404)
      end
    end

    context "when user is not an admin" do
      it "should raise the right error" do
        sign_in(Fabricate(:user))
        public_send(action, route)
        expect(response.status).to eq(404)
      end
    end
  end

  describe "listing providers" do
    include_examples "admin constraints",
                     "get",
                     "/admin/plugins/discourse-chat-integration/providers.json"

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "should return the right response" do
        get "/admin/plugins/discourse-chat-integration/providers.json"

        expect(response.status).to eq(200)

        json = response.parsed_body

        expect(json["enabled_providers"].size).to eq(1)
        expect(json["disabled_providers"].size).to be > 0

        expect(json["enabled_providers"].find { |h| h["name"] == "dummy" }).to eq(
          "name" => "dummy",
          "id" => "dummy",
          "channel_parameters" => [],
        )
      end

      it "returns available providers sorted by popularity descending then name" do
        get "/admin/plugins/discourse-chat-integration/providers.json"

        names = response.parsed_body["disabled_providers"].map { |p| p["name"] }

        expect(names).not_to be_empty
        expect(names).not_to include("dummy")

        # Providers with higher popularity scores should appear first
        slack_index = names.index("slack")
        webex_index = names.index("webex")
        expect(slack_index).not_to be_nil
        expect(webex_index).not_to be_nil
        expect(slack_index).to be < webex_index
      end
    end
  end

  describe "setup provider" do
    include_examples "admin constraints",
                     "post",
                     "/admin/plugins/discourse-chat-integration/setup-provider"

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "enables the provider site setting" do
        SiteSetting.dummy_provider_enabled = false
        post "/admin/plugins/discourse-chat-integration/setup-provider",
             params: {
               provider: {
                 name: "dummy",
               },
             },
             as: :json
        expect(response.status).to eq(200)

        expect(SiteSetting.dummy_provider_enabled).to eq(true)
      end

      context "when the provider is unknown" do
        it "returns an error" do
          post "/admin/plugins/discourse-chat-integration/setup-provider",
               params: {
                 provider: {
                   name: "nonexistent_provider",
                 },
               },
               as: :json

          expect(response.status).to eq(422)
        end
      end

      context "when the provider is already enabled" do
        it "returns an error" do
          SiteSetting.dummy_provider_enabled = true
          post "/admin/plugins/discourse-chat-integration/setup-provider",
               params: {
                 provider: {
                   name: "dummy",
                 },
               },
               as: :json

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("chat_integration.errors.provider_already_enabled", name: "dummy"),
          )
        end
      end

      context "when setting up slack" do
        before do
          SiteSetting.chat_integration_slack_enabled = false
          SiteSetting.chat_integration_slack_access_token = ""
        end

        it "returns success and enables slack when the token is valid" do
          stub_request(:post, "https://slack.com/api/auth.test").to_return(
            body: { ok: true }.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
          )

          post "/admin/plugins/discourse-chat-integration/setup-provider",
               params: {
                 provider: {
                   name: "slack",
                 },
                 provider_site_settings: {
                   chat_integration_slack_access_token: "xoxb-from-request",
                 },
               },
               as: :json

          expect(response.status).to eq(200)
          expect(SiteSetting.chat_integration_slack_enabled).to eq(true)
          expect(SiteSetting.chat_integration_slack_access_token).to eq("xoxb-from-request")
        end

        it "returns success when both token and webhook URL are provided" do
          stub_request(:post, "https://slack.com/api/auth.test").to_return(
            body: { ok: true }.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
          )

          hook = "https://hooks.slack.com/services/t00000000/b00000000/xxxxxxxxxxxxxxxxxxxxxxxx"

          post "/admin/plugins/discourse-chat-integration/setup-provider",
               params: {
                 provider: {
                   name: "slack",
                 },
                 provider_site_settings: {
                   chat_integration_slack_access_token: "xoxb-both",
                   chat_integration_slack_outbound_webhook_url: hook,
                 },
               },
               as: :json

          expect(response.status).to eq(200)
          expect(SiteSetting.chat_integration_slack_enabled).to eq(true)
          expect(SiteSetting.chat_integration_slack_access_token).to eq("xoxb-both")
          expect(SiteSetting.chat_integration_slack_outbound_webhook_url).to eq(hook)
        end

        it "returns success when only webhook URL is provided" do
          hook = "https://hooks.slack.com/services/t00000000/b00000000/xxxxxxxxxxxxxxxxxxxxxxxx"

          post "/admin/plugins/discourse-chat-integration/setup-provider",
               params: {
                 provider: {
                   name: "slack",
                 },
                 provider_site_settings: {
                   chat_integration_slack_outbound_webhook_url: hook,
                 },
               },
               as: :json
          expect(response.status).to eq(200)
          expect(SiteSetting.chat_integration_slack_enabled).to eq(true)
          expect(SiteSetting.chat_integration_slack_outbound_webhook_url).to eq(hook)
        end

        it "returns error_key when slack rejects the token" do
          stub_request(:post, "https://slack.com/api/auth.test").to_return(
            body: { ok: false, error: "invalid_auth" }.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
          )

          post "/admin/plugins/discourse-chat-integration/setup-provider",
               params: {
                 provider: {
                   name: "slack",
                 },
                 provider_site_settings: {
                   chat_integration_slack_access_token: "bad",
                 },
               },
               as: :json

          expect(response.status).to eq(422)
          expect(response.parsed_body["error_key"]).to eq(
            "chat_integration.provider.slack.errors.auth_error",
          )
        end
      end

      context "when setting up telegram" do
        before do
          SiteSetting.chat_integration_telegram_enabled = false
          SiteSetting.chat_integration_telegram_access_token = ""
        end

        it "returns success when setWebhook succeeds" do
          stub_request(:post, %r{https://api\.telegram\.org/botreqtok/setWebhook}).to_return(
            body: { ok: true }.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
          )

          post "/admin/plugins/discourse-chat-integration/setup-provider",
               params: {
                 provider: {
                   name: "telegram",
                 },
                 provider_site_settings: {
                   chat_integration_telegram_access_token: "reqtok",
                 },
               },
               as: :json

          expect(response.status).to eq(200)
          expect(SiteSetting.chat_integration_telegram_enabled).to eq(true)
          expect(SiteSetting.chat_integration_telegram_access_token).to eq("reqtok")
        end

        it "returns error_key when setWebhook fails" do
          stub_request(:post, %r{https://api\.telegram\.org/botbadtok/setWebhook}).to_return(
            body: { ok: false }.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
          )

          post "/admin/plugins/discourse-chat-integration/setup-provider",
               params: {
                 provider: {
                   name: "telegram",
                 },
                 provider_site_settings: {
                   chat_integration_telegram_access_token: "badtok",
                 },
               },
               as: :json

          expect(response.status).to eq(422)
          expect(response.parsed_body["error_key"]).to eq(
            "chat_integration.provider.telegram.errors.webhook_setup_failed",
          )
        end
      end
    end
  end

  describe "testing channels" do
    include_examples "admin constraints",
                     "get",
                     "/admin/plugins/discourse-chat-integration/test.json"

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "should return the right response" do
        post "/admin/plugins/discourse-chat-integration/test.json",
             params: {
               channel_id: channel.id,
               topic_id: topic.id,
             }

        expect(response.status).to eq(200)
      end

      it "should fail for invalid channel" do
        post "/admin/plugins/discourse-chat-integration/test.json",
             params: {
               channel_id: 999,
               topic_id: topic.id,
             }

        expect(response.status).to eq(422)
      end
    end
  end

  describe "viewing channels" do
    include_examples "admin constraints",
                     "get",
                     "/admin/plugins/discourse-chat-integration/channels.json"

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "should return the right response" do
        rule =
          DiscourseChatIntegration::Rule.create(
            channel: channel,
            filter: "follow",
            category_id: category.id,
            tags: [tag.name],
          )

        get "/admin/plugins/discourse-chat-integration/channels.json", params: { provider: "dummy" }

        expect(response.status).to eq(200)

        channels = response.parsed_body["channels"]

        expect(channels.count).to eq(1)

        expect(channels.first).to eq(
          "id" => channel.id,
          "provider" => "dummy",
          "data" => {
          },
          "error_key" => nil,
          "error_info" => nil,
          "rules" => [
            {
              "id" => rule.id,
              "type" => "normal",
              "group_name" => nil,
              "group_id" => nil,
              "filter" => "follow",
              "channel_id" => channel.id,
              "category_id" => category.id,
              "tags" => [tag.name],
            },
          ],
        )
      end

      it "should fail for invalid provider" do
        get "/admin/plugins/discourse-chat-integration/channels.json",
            params: {
              provider: "someprovider",
            }
        expect(response.status).to eq(400)
      end
    end
  end

  describe "adding a channel" do
    include_examples "admin constraints",
                     "post",
                     "/admin/plugins/discourse-chat-integration/channels.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able to add a new channel" do
        post "/admin/plugins/discourse-chat-integration/channels.json",
             params: {
               channel: {
                 provider: "dummy",
                 data: {
                 },
               },
             }

        expect(response.status).to eq(200)

        channel = DiscourseChatIntegration::Channel.all.last

        expect(channel.provider).to eq("dummy")
      end

      it "should fail for invalid params" do
        post "/admin/plugins/discourse-chat-integration/channels.json",
             params: {
               channel: {
                 provider: "dummy2",
                 data: {
                   val: "something with whitespace",
                 },
               },
             }

        expect(response.status).to eq(422)
      end
    end
  end

  describe "updating a channel" do
    let(:channel) do
      DiscourseChatIntegration::Channel.create(provider: "dummy2", data: { val: "something" })
    end

    include_examples "admin constraints",
                     "put",
                     "/admin/plugins/discourse-chat-integration/channels/1.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able update a channel" do
        put "/admin/plugins/discourse-chat-integration/channels/#{channel.id}.json",
            params: {
              channel: {
                data: {
                  val: "something-else",
                },
              },
            }

        expect(response.status).to eq(200)

        channel = DiscourseChatIntegration::Channel.all.last
        expect(channel.data).to eq("val" => "something-else")
      end

      it "should fail for invalid params" do
        put "/admin/plugins/discourse-chat-integration/channels/#{channel.id}.json",
            params: {
              channel: {
                data: {
                  val: "something with whitespace",
                },
              },
            }

        expect(response.status).to eq(422)
      end
    end
  end

  describe "deleting a channel" do
    let(:channel) { DiscourseChatIntegration::Channel.create(provider: "dummy", data: {}) }

    include_examples "admin constraints",
                     "delete",
                     "/admin/plugins/discourse-chat-integration/channels/1.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able delete a channel" do
        delete "/admin/plugins/discourse-chat-integration/channels/#{channel.id}.json"

        expect(response.status).to eq(200)
        expect(DiscourseChatIntegration::Channel.all.size).to eq(0)
      end
    end
  end

  describe "adding a rule" do
    include_examples "admin constraints",
                     "put",
                     "/admin/plugins/discourse-chat-integration/rules.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able to add a new rule" do
        post "/admin/plugins/discourse-chat-integration/rules.json",
             params: {
               rule: {
                 channel_id: channel.id,
                 category_id: category.id,
                 filter: "watch",
                 tags: [tag.name],
               },
             }

        expect(response.status).to eq(200)

        rule = DiscourseChatIntegration::Rule.all.last

        expect(rule.channel_id).to eq(channel.id)
        expect(rule.category_id).to eq(category.id)
        expect(rule.filter).to eq("watch")
        expect(rule.tags).to eq([tag.name])
      end

      it "should fail for invalid params" do
        post "/admin/plugins/discourse-chat-integration/rules.json",
             params: {
               rule: {
                 channel_id: channel.id,
                 category_id: category.id,
                 filter: "watch",
                 tags: ["somenonexistanttag"],
               },
             }

        expect(response.status).to eq(422)
      end
    end
  end

  describe "updating a rule" do
    let(:rule) do
      DiscourseChatIntegration::Rule.create(
        channel: channel,
        filter: "follow",
        category_id: category.id,
        tags: [tag.name],
      )
    end

    include_examples "admin constraints",
                     "put",
                     "/admin/plugins/discourse-chat-integration/rules/1.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able update a rule" do
        put "/admin/plugins/discourse-chat-integration/rules/#{rule.id}.json",
            params: {
              rule: {
                channel_id: channel.id,
                category_id: category2.id,
                filter: rule.filter,
                tags: rule.tags,
              },
            }

        expect(response.status).to eq(200)

        rule = DiscourseChatIntegration::Rule.all.last
        expect(rule.category_id).to eq(category2.id)
      end

      it "should fail for invalid params" do
        put "/admin/plugins/discourse-chat-integration/rules/#{rule.id}.json",
            params: {
              rule: {
                channel_id: channel.id,
                category_id: category.id,
                filter: "watch",
                tags: ["somenonexistanttag"],
              },
            }

        expect(response.status).to eq(422)
      end
    end
  end

  describe "deleting a rule" do
    let(:rule) do
      DiscourseChatIntegration::Rule.create!(
        channel_id: channel.id,
        filter: "follow",
        category_id: category.id,
        tags: [tag.name],
      )
    end

    include_examples "admin constraints",
                     "delete",
                     "/admin/plugins/discourse-chat-integration/rules/1.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able delete a rule" do
        delete "/admin/plugins/discourse-chat-integration/rules/#{rule.id}.json"

        expect(response.status).to eq(200)
        expect(DiscourseChatIntegration::Rule.all.size).to eq(0)
      end
    end
  end
end
