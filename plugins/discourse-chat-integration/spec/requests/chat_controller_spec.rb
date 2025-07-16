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

  before { SiteSetting.chat_integration_enabled = true }

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
    include_examples "admin constraints", "get", "/admin/plugins/chat-integration/providers.json"

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "should return the right response" do
        get "/admin/plugins/chat-integration/providers.json"

        expect(response.status).to eq(200)

        json = response.parsed_body

        expect(json["providers"].size).to eq(2)

        expect(json["providers"].find { |h| h["name"] == "dummy" }).to eq(
          "name" => "dummy",
          "id" => "dummy",
          "channel_parameters" => [],
        )
      end
    end
  end

  describe "testing channels" do
    include_examples "admin constraints", "get", "/admin/plugins/chat-integration/test.json"

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "should return the right response" do
        post "/admin/plugins/chat-integration/test.json",
             params: {
               channel_id: channel.id,
               topic_id: topic.id,
             }

        expect(response.status).to eq(200)
      end

      it "should fail for invalid channel" do
        post "/admin/plugins/chat-integration/test.json",
             params: {
               channel_id: 999,
               topic_id: topic.id,
             }

        expect(response.status).to eq(422)
      end
    end
  end

  describe "viewing channels" do
    include_examples "admin constraints", "get", "/admin/plugins/chat-integration/channels.json"

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

        get "/admin/plugins/chat-integration/channels.json", params: { provider: "dummy" }

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
        get "/admin/plugins/chat-integration/channels.json", params: { provider: "someprovider" }
        expect(response.status).to eq(400)
      end
    end
  end

  describe "adding a channel" do
    include_examples "admin constraints", "post", "/admin/plugins/chat-integration/channels.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able to add a new channel" do
        post "/admin/plugins/chat-integration/channels.json",
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
        post "/admin/plugins/chat-integration/channels.json",
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

    include_examples "admin constraints", "put", "/admin/plugins/chat-integration/channels/1.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able update a channel" do
        put "/admin/plugins/chat-integration/channels/#{channel.id}.json",
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
        put "/admin/plugins/chat-integration/channels/#{channel.id}.json",
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
                     "/admin/plugins/chat-integration/channels/1.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able delete a channel" do
        delete "/admin/plugins/chat-integration/channels/#{channel.id}.json"

        expect(response.status).to eq(200)
        expect(DiscourseChatIntegration::Channel.all.size).to eq(0)
      end
    end
  end

  describe "adding a rule" do
    include_examples "admin constraints", "put", "/admin/plugins/chat-integration/rules.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able to add a new rule" do
        post "/admin/plugins/chat-integration/rules.json",
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
        post "/admin/plugins/chat-integration/rules.json",
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

    include_examples "admin constraints", "put", "/admin/plugins/chat-integration/rules/1.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able update a rule" do
        put "/admin/plugins/chat-integration/rules/#{rule.id}.json",
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
        put "/admin/plugins/chat-integration/rules/#{rule.id}.json",
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

    include_examples "admin constraints", "delete", "/admin/plugins/chat-integration/rules/1.json"

    context "as an admin" do
      before { sign_in(admin) }

      it "should be able delete a rule" do
        delete "/admin/plugins/chat-integration/rules/#{rule.id}.json"

        expect(response.status).to eq(200)
        expect(DiscourseChatIntegration::Rule.all.size).to eq(0)
      end
    end
  end
end
