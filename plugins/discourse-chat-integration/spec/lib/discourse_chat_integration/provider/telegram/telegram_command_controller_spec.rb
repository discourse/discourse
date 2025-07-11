# frozen_string_literal: true

require "rails_helper"

describe "Telegram Command Controller", type: :request do
  let(:category) { Fabricate(:category) }
  let!(:chan1) do
    DiscourseChatIntegration::Channel.create!(
      provider: "telegram",
      data: {
        name: "Amazing Channel",
        chat_id: "123",
      },
    )
  end
  let!(:webhook_stub) do
    stub_request(:post, "https://api.telegram.org/botTOKEN/setWebhook").to_return(
      body: "{\"ok\":true}",
    )
  end

  describe "with plugin disabled" do
    it "should return a 404" do
      post "/chat-integration/telegram/command/abcd.json"
      expect(response.status).to eq(404)
    end
  end

  describe "with plugin enabled and provider disabled" do
    before do
      SiteSetting.chat_integration_enabled = true
      SiteSetting.chat_integration_telegram_enabled = false
    end

    it "should return a 404" do
      post "/chat-integration/telegram/command/abcd.json"
      expect(response.status).to eq(404)
    end
  end

  describe "slash commands endpoint" do
    before do
      SiteSetting.chat_integration_enabled = true
      SiteSetting.chat_integration_telegram_access_token = "TOKEN"
      SiteSetting.chat_integration_telegram_enabled = true
      SiteSetting.chat_integration_telegram_secret = "shhh"
    end

    let!(:stub) do
      stub_request(:post, "https://api.telegram.org/botTOKEN/sendMessage").to_return(
        body: "{\"ok\":true}",
      )
    end

    describe "when forum is private" do
      it "should not redirect to login page" do
        SiteSetting.login_required = true

        post "/chat-integration/telegram/command/shhh.json",
             params: {
               message: {
                 chat: {
                   id: 123,
                 },
                 text: "/help",
               },
             }

        expect(response.status).to eq(200)
      end
    end

    describe "when the token is invalid" do
      it "should raise the right error" do
        post "/chat-integration/telegram/command/blah.json",
             params: {
               message: {
                 chat: {
                   id: 123,
                 },
                 text: "/help",
               },
             }

        expect(response.status).to eq(403)
      end
    end

    describe "when token has not been set" do
      it "should raise the right error" do
        SiteSetting.chat_integration_telegram_access_token = ""
        post "/chat-integration/telegram/command/blah.json",
             params: {
               message: {
                 chat: {
                   id: 123,
                 },
                 text: "/help",
               },
             }

        expect(response.status).to eq(403)
      end
    end

    describe "when token is valid" do
      let(:token) { "TOKEN" }

      before { SiteSetting.chat_integration_telegram_enable_slash_commands = true }

      describe "add new rule" do
        it "should add a new rule correctly" do
          post "/chat-integration/telegram/command/shhh.json",
               params: {
                 message: {
                   chat: {
                     id: 123,
                   },
                   text: "/watch #{category.slug}",
                 },
               }

          expect(response.status).to eq(200)
          expect(stub).to have_been_requested.once

          rule = DiscourseChatIntegration::Rule.all.first
          expect(rule.channel).to eq(chan1)
          expect(rule.filter).to eq("watch")
          expect(rule.category_id).to eq(category.id)
          expect(rule.tags).to eq(nil)
        end

        it "should add a new rule correctly using group chat syntax" do
          post "/chat-integration/telegram/command/shhh.json",
               params: {
                 message: {
                   chat: {
                     id: 123,
                   },
                   text: "/watch@my-awesome-bot #{category.slug}",
                 },
               }

          expect(response.status).to eq(200)
          expect(stub).to have_been_requested.once

          rule = DiscourseChatIntegration::Rule.all.first
          expect(rule.channel).to eq(chan1)
          expect(rule.filter).to eq("watch")
          expect(rule.category_id).to eq(category.id)
          expect(rule.tags).to eq(nil)
        end

        describe "from an unknown channel" do
          it "does nothing" do
            post "/chat-integration/telegram/command/shhh.json",
                 params: {
                   message: {
                     chat: {
                       id: 456,
                     },
                     text: "/watch #{category.slug}",
                   },
                 }

            expect(DiscourseChatIntegration::Rule.all.size).to eq(0)
            expect(DiscourseChatIntegration::Channel.all.size).to eq(1)
          end
        end
      end

      it "should respond only to a specific command in a broadcast channel" do
        post "/chat-integration/telegram/command/shhh.json",
             params: {
               channel_post: {
                 chat: {
                   id: 123,
                 },
                 text: "something",
               },
             }

        expect(response.status).to eq(200)
        expect(stub).to have_been_requested.times(0)

        post "/chat-integration/telegram/command/shhh.json",
             params: {
               channel_post: {
                 chat: {
                   id: 123,
                 },
                 text: "/getchatid",
               },
             }

        expect(response.status).to eq(200)
        expect(stub).to have_been_requested.times(1)
      end

      context "when 'text' is missing" do
        it "does not break" do
          post "/chat-integration/telegram/command/shhh.json",
               params: {
                 message: {
                   chat: {
                     id: 123,
                   },
                 },
               }

          expect(response).to have_http_status :ok
          expect(DiscourseChatIntegration::Rule.count).to eq(0)
          expect(DiscourseChatIntegration::Channel.count).to eq(1)
        end
      end
    end
  end
end
