# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::CreatePost::V1 do
  fab!(:admin)
  fab!(:topic_owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: topic_owner, raw: "First post") }
  fab!(:topic) { first_post.topic }

  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:create_post")
    end
  end

  describe "#execute_single" do
    it "creates a reply for the configured user" do
      result = nil

      expect do
        result =
          described_class.new(configuration: {}).execute_single(
            {},
            item: {
              "json" => {
              },
            },
            config: {
              "topic_id" => topic.id.to_s,
              "raw" => "Workflow reply",
              "user_id" => admin.id.to_s,
            },
          )
      end.to change { topic.posts.count }.by(1)

      reply = topic.posts.order(:id).last

      expect(reply.raw).to eq("Workflow reply")
      expect(reply.user_id).to eq(admin.id)
      expect(result[:post]).to include(
        id: reply.id,
        post_number: reply.post_number,
        raw: "Workflow reply",
        reply_to_post_number: nil,
        user_id: admin.id,
        username: admin.username,
      )
    end

    it "falls back to the system user when no user is configured" do
      described_class.new(configuration: {}).execute_single(
        {},
        item: {
          "json" => {
          },
        },
        config: {
          "topic_id" => topic.id.to_s,
          "raw" => "Created by workflows",
        },
      )

      expect(topic.posts.order(:id).last.user_id).to eq(Discourse.system_user.id)
    end

    it "creates a reply to a specific post number" do
      described_class.new(configuration: {}).execute_single(
        {},
        item: {
          "json" => {
          },
        },
        config: {
          "topic_id" => topic.id.to_s,
          "raw" => "Threaded reply",
          "reply_to_post_number" => first_post.post_number.to_s,
        },
      )

      expect(topic.posts.order(:id).last.reply_to_post_number).to eq(first_post.post_number)
    end

    it "raises when the user cannot be found" do
      expect do
        described_class.new(configuration: {}).execute_single(
          {},
          item: {
            "json" => {
            },
          },
          config: {
            "topic_id" => topic.id.to_s,
            "raw" => "Workflow reply",
            "user_id" => -999,
          },
        )
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises when the topic is closed" do
      topic.update!(closed: true)

      expect do
        described_class.new(configuration: {}).execute_single(
          {},
          item: {
            "json" => {
            },
          },
          config: {
            "topic_id" => topic.id.to_s,
            "raw" => "Workflow reply",
          },
        )
      end.to raise_error(
        ActiveRecord::RecordNotSaved,
        /Cannot create a post in a closed or archived topic/,
      )
    end

    it "raises when the topic is archived" do
      topic.update!(archived: true)

      expect do
        described_class.new(configuration: {}).execute_single(
          {},
          item: {
            "json" => {
            },
          },
          config: {
            "topic_id" => topic.id.to_s,
            "raw" => "Workflow reply",
          },
        )
      end.to raise_error(
        ActiveRecord::RecordNotSaved,
        /Cannot create a post in a closed or archived topic/,
      )
    end

    it "raises when topic does not exist" do
      expect do
        described_class.new(configuration: {}).execute_single(
          {},
          item: {
            "json" => {
            },
          },
          config: {
            "topic_id" => "-1",
            "raw" => "Workflow reply",
          },
        )
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#execute" do
    it "resolves expressions for each input item" do
      result =
        described_class.new(
          configuration: {
            "topic_id" => "={{ trigger.topic_id }}",
            "raw" => "=Hello {{ $json.name }}",
            "reply_to_post_number" => "={{ trigger.reply_to_post_number }}",
            "user_id" => "={{ trigger.user_id }}",
          },
        ).execute(
          {
            "trigger" => {
              "topic_id" => topic.id,
              "reply_to_post_number" => first_post.post_number,
              "user_id" => admin.id,
            },
          },
          input_items: [{ "json" => { "name" => "Ada" } }],
          node_context: {
          },
        )

      reply = topic.posts.order(:id).last

      expect(reply.raw).to eq("Hello Ada")
      expect(reply.reply_to_post_number).to eq(first_post.post_number)
      expect(reply.user_id).to eq(admin.id)
      expect(result.first["json"]["post"]).to include(
        "id" => reply.id,
        "post_number" => reply.post_number,
        "raw" => "Hello Ada",
      )
    end
  end
end
