# frozen_string_literal: true

require "rails_helper"

describe "Slack Command Controller", type: :request do
  before { Discourse.cache.clear }

  let(:category) { Fabricate(:category) }
  let(:tag) { Fabricate(:tag) }
  let(:tag2) { Fabricate(:tag) }
  let!(:chan1) do
    DiscourseChatIntegration::Channel.create!(provider: "slack", data: { identifier: "#welcome" })
  end

  describe "with plugin disabled" do
    it "should return a 404" do
      post "/chat-integration/slack/command.json"
      expect(response.status).to eq(404)
    end
  end

  describe "with plugin enabled and provider disabled" do
    before do
      SiteSetting.chat_integration_enabled = true
      SiteSetting.chat_integration_slack_enabled = false
    end

    it "should return a 404" do
      post "/chat-integration/slack/command.json"
      expect(response.status).to eq(404)
    end
  end

  describe "slash commands endpoint" do
    before do
      SiteSetting.chat_integration_enabled = true
      SiteSetting.chat_integration_slack_outbound_webhook_url =
        "https://hooks.slack.com/services/abcde"
      SiteSetting.chat_integration_slack_enabled = true
    end

    describe "when forum is private" do
      it "should not redirect to login page" do
        SiteSetting.login_required = true
        token = "sometoken"
        SiteSetting.chat_integration_slack_incoming_webhook_token = token

        post "/chat-integration/slack/command.json", params: { text: "help", token: token }

        expect(response.status).to eq(200)
      end
    end

    describe "when the token is invalid" do
      it "should raise the right error" do
        post "/chat-integration/slack/command.json", params: { text: "help" }
        expect(response.status).to eq(400)
      end
    end

    describe "backwards compatibility with discourse-slack-official" do
      it "should return the right response" do
        token = "secret sauce"
        SiteSetting.chat_integration_slack_incoming_webhook_token = token

        post "/slack/command.json", params: { text: "help", token: token }

        expect(response.status).to eq(200)
        expect(response.parsed_body["text"]).to be_present
      end
    end

    describe "when incoming webhook token has not been set" do
      it "should raise the right error" do
        post "/chat-integration/slack/command.json", params: { text: "help", token: "some token" }

        expect(response.status).to eq(403)
      end
    end

    describe "when token is valid" do
      let(:token) { "Secret Sauce" }

      # No need to test every single command here, that's tested
      # by helper_spec upstream

      before { SiteSetting.chat_integration_slack_incoming_webhook_token = token }

      describe "add new rule" do
        it "should add a new rule correctly" do
          post "/chat-integration/slack/command.json",
               params: {
                 text: "watch #{category.slug}",
                 channel_name: "welcome",
                 token: token,
               }

          json = response.parsed_body

          expect(json["text"]).to eq(I18n.t("chat_integration.provider.slack.create.created"))

          rule = DiscourseChatIntegration::Rule.all.first
          expect(rule.channel).to eq(chan1)
          expect(rule.filter).to eq("watch")
          expect(rule.category_id).to eq(category.id)
          expect(rule.tags).to eq(nil)
        end

        describe "from an unknown channel" do
          it "creates the channel" do
            post "/chat-integration/slack/command.json",
                 params: {
                   text: "watch #{category.slug}",
                   channel_name: "general",
                   token: token,
                 }

            json = response.parsed_body

            expect(json["text"]).to eq(I18n.t("chat_integration.provider.slack.create.created"))

            chan =
              DiscourseChatIntegration::Channel
                .with_provider("slack")
                .with_data_value("identifier", "#general")
                .first
            expect(chan.provider).to eq("slack")

            rule = chan.rules.first
            expect(rule.filter).to eq("watch")
            expect(rule.category_id).to eq(category.id)
            expect(rule.tags).to eq(nil)
          end
        end
      end

      describe "post transcript" do
        let(:messages_fixture) do
          [
            {
              type: "message",
              user: "U6JSSESES",
              text: "Yeah, should make posting slack transcripts much easier",
              ts: "1501801665.062694",
            },
            {
              type: "message",
              user: "U5Z773QLS",
              text: "Oooh a new discourse plugin???",
              ts: "1501801643.056375",
            },
            { type: "message", user: "U6E2W7R8C", text: "Which one?", ts: "1501801634.053761" },
            {
              type: "message",
              user: "U6JSSESES",
              text:
                "So, who's interested in the new <https://meta.discourse.org|discourse plugin>?",
              ts: "1501801629.052212",
            },
            {
              text: "",
              username: "Test Community",
              bot_id: "B6C6JNUDN",
              attachments: [
                {
                  author_name: "@david",
                  fallback: "Discourse can now be integrated with Mattermost! - @david",
                  text: "Hey <http://localhost/groups/team|@team>, what do you think about this?",
                  title: "Discourse can now be integrated with Mattermost! [Announcements] ",
                  id: 1,
                  title_link:
                    "http://localhost:3000/t/discourse-can-now-be-integrated-with-mattermost/51/4",
                  color: "283890",
                  mrkdwn_in: ["text"],
                },
              ],
              type: "message",
              subtype: "bot_message",
              ts: "1501615820.949638",
            },
            {
              type: "message",
              user: "U5Z773QLS",
              text: "Let’s try some *bold text*",
              ts: "1501093331.439776",
            },
          ]
        end

        before { SiteSetting.chat_integration_slack_access_token = "abcde" }

        context "with valid slack responses" do
          before do
            stub_request(:post, "https://slack.com/api/users.list").to_return(
              body:
                '{"ok":true,"members":[{"id":"U5Z773QLS","profile":{"display_name":"david","real_name":"david","icon_24":"https://example.com/avatar"}}],"response_metadata":{"next_cursor":""}}',
            )
            stub_request(:post, "https://slack.com/api/conversations.history").to_return(
              body: { ok: true, messages: messages_fixture }.to_json,
            )
          end

          it "generates the transcript UI properly" do
            command_stub =
              stub_request(:post, "https://slack.com/commands/1234").with(
                body: /attachments/,
              ).to_return(body: { ok: true }.to_json)

            post "/chat-integration/slack/command.json",
                 params: {
                   text: "post",
                   response_url: "https://hooks.slack.com/commands/1234",
                   channel_name: "general",
                   channel_id: "C6029G78F",
                   token: token,
                 }

            expect(command_stub).to have_been_requested
          end

          it "can select by url" do
            command_stub =
              stub_request(:post, "https://slack.com/commands/1234").with(
                body: /1501801629\.052212/,
              ).to_return(body: { ok: true }.to_json)

            post "/chat-integration/slack/command.json",
                 params: {
                   text:
                     "post https://sometestslack.slack.com/archives/C6029G78F/p1501801629052212",
                   response_url: "https://hooks.slack.com/commands/1234",
                   channel_name: "general",
                   channel_id: "C6029G78F",
                   token: token,
                 }

            expect(command_stub).to have_been_requested
          end

          it "can select by url with thread parameter" do
            replies_stub =
              stub_request(:post, "https://slack.com/api/conversations.replies").with(
                body: /1501801629\.052212/,
              ).to_return(body: { ok: true, messages: messages_fixture }.to_json)

            command_stub =
              stub_request(:post, "https://slack.com/commands/1234").to_return(
                body: { ok: true }.to_json,
              )

            post "/chat-integration/slack/command.json",
                 params: {
                   text:
                     "post https://sometestslack.slack.com/archives/C6029G78F/p1501201669054212?thread_ts=1501801629.052212",
                   response_url: "https://hooks.slack.com/commands/1234",
                   channel_name: "general",
                   channel_id: "C6029G78F",
                   token: token,
                 }

            expect(command_stub).to have_been_requested
            expect(replies_stub).to have_been_requested
          end

          it "can select by thread" do
            replies_stub =
              stub_request(:post, "https://slack.com/api/conversations.replies").with(
                body: /1501801629\.052212/,
              ).to_return(body: { ok: true, messages: messages_fixture }.to_json)

            command_stub =
              stub_request(:post, "https://slack.com/commands/1234").to_return(
                body: { ok: true }.to_json,
              )

            post "/chat-integration/slack/command.json",
                 params: {
                   text:
                     "post thread https://sometestslack.slack.com/archives/C6029G78F/p1501801629052212",
                   response_url: "https://hooks.slack.com/commands/1234",
                   channel_name: "general",
                   channel_id: "C6029G78F",
                   token: token,
                 }

            expect(command_stub).to have_been_requested
            expect(replies_stub).to have_been_requested
          end

          it "can select by count" do
            command_stub =
              stub_request(:post, "https://slack.com/commands/1234").with(
                body: /1501801629\.052212/,
              ).to_return(body: { ok: true }.to_json)

            post "/chat-integration/slack/command.json",
                 params: {
                   text: "post 4",
                   response_url: "https://hooks.slack.com/commands/1234",
                   channel_name: "general",
                   channel_id: "C6029G78F",
                   token: token,
                 }

            expect(command_stub).to have_been_requested
          end

          it "can auto select" do
            command_stub =
              stub_request(:post, "https://slack.com/commands/1234").with(
                body: /1501615820\.949638/,
              ).to_return(body: { ok: true }.to_json)

            post "/chat-integration/slack/command.json",
                 params: {
                   text: "post",
                   response_url: "https://hooks.slack.com/commands/1234",
                   channel_name: "general",
                   channel_id: "C6029G78F",
                   token: token,
                 }

            expect(command_stub).to have_been_requested
          end

          it "supports using shortcuts to create a thread transcript" do
            replies_stub =
              stub_request(:post, "https://slack.com/api/conversations.replies").with(
                body: /1501801629\.052212/,
              ).to_return(body: { ok: true, messages: messages_fixture }.to_json)

            view_open_stub =
              stub_request(:post, "https://slack.com/api/views.open").with(
                body: /TRIGGERID/,
              ).to_return(body: { ok: true, view: { id: "VIEWID" } }.to_json)

            view_update_stub =
              stub_request(:post, "https://slack.com/api/views.update").with(
                body: /VIEWID/,
              ).to_return(body: { ok: true }.to_json)

            post "/chat-integration/slack/interactive.json",
                 params: {
                   payload: {
                     type: "message_action",
                     channel: {
                       name: "general",
                       id: "C6029G78F",
                     },
                     trigger_id: "TRIGGERID",
                     message: {
                       thread_ts: "1501801629.052212",
                     },
                     token: token,
                   }.to_json,
                 }

            expect(response.status).to eq(200)

            expect(view_open_stub).to have_been_requested
            expect(view_update_stub).to have_been_requested
          end
        end

        it "deals with failed API calls correctly" do
          command_stub =
            stub_request(:post, "https://slack.com/commands/1234").with(
              body: {
                text: I18n.t("chat_integration.provider.slack.transcript.error_users"),
              },
            ).to_return(body: { ok: true }.to_json)

          stub_request(:post, "https://slack.com/api/users.list").to_return(status: 403)

          post "/chat-integration/slack/command.json",
               params: {
                 text: "post 2",
                 response_url: "https://hooks.slack.com/commands/1234",
                 channel_name: "general",
                 channel_id: "C6029G78F",
                 token: token,
               }

          json = response.parsed_body

          expect(json["text"]).to include(
            I18n.t("chat_integration.provider.slack.transcript.loading"),
          )

          expect(command_stub).to have_been_requested
        end

        it "errors correctly if there is no api key" do
          SiteSetting.chat_integration_slack_access_token = ""

          post "/chat-integration/slack/command.json",
               params: {
                 text: "post 2",
                 response_url: "https://hooks.slack.com/commands/1234",
                 channel_name: "general",
                 channel_id: "C6029G78F",
                 token: token,
               }

          json = response.parsed_body

          expect(json["text"]).to include(
            I18n.t("chat_integration.provider.slack.transcript.api_required"),
          )
        end
      end
    end
  end
end
