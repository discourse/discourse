# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::CreatePost::V1 do
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

  def execute_node(configuration:, item:, run_as_user: Discourse.system_user)
    action = described_class.new(configuration: configuration)
    input_items = [item]
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => item.fetch("json") { {} } })
    exec_ctx =
      DiscourseWorkflows::NodeExecutionContext.new(
        input_items: input_items,
        run_as_user: run_as_user,
        resolver: resolver,
      )
    items = action.execute(exec_ctx)[0]
    items.first["json"]
  end

  describe "#execute" do
    it "creates a reply for the configured user" do
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "topic_id" => topic.id.to_s,
              "raw" => "Workflow reply",
              "user_id" => admin.id.to_s,
            },
            item: {
              "json" => {
              },
            },
          )
      end.to change { topic.posts.count }.by(1)

      reply = topic.posts.order(:id).last

      expect(reply.raw).to eq("Workflow reply")
      expect(reply.user_id).to eq(admin.id)
      expect(result["post"]).to include(
        "id" => reply.id,
        "post_number" => reply.post_number,
        "raw" => "Workflow reply",
        "reply_to_post_number" => nil,
        "user_id" => admin.id,
        "username" => admin.username,
      )
    end

    it "falls back to the system user when no user is configured" do
      execute_node(
        configuration: {
          "topic_id" => topic.id.to_s,
          "raw" => "Created by workflows",
        },
        item: {
          "json" => {
          },
        },
      )

      expect(topic.posts.order(:id).last.user_id).to eq(Discourse.system_user.id)
    end

    it "creates a reply to a specific post number" do
      execute_node(
        configuration: {
          "topic_id" => topic.id.to_s,
          "raw" => "Threaded reply",
          "reply_to_post_number" => first_post.post_number.to_s,
        },
        item: {
          "json" => {
          },
        },
      )

      expect(topic.posts.order(:id).last.reply_to_post_number).to eq(first_post.post_number)
    end

    it "raises when the user cannot be found" do
      expect do
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
            "raw" => "Workflow reply",
            "user_id" => -999,
          },
          item: {
            "json" => {
            },
          },
        )
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises when the topic is closed" do
      topic.update!(closed: true)

      expect do
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
            "raw" => "Workflow reply",
          },
          item: {
            "json" => {
            },
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
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
            "raw" => "Workflow reply",
          },
          item: {
            "json" => {
            },
          },
        )
      end.to raise_error(
        ActiveRecord::RecordNotSaved,
        /Cannot create a post in a closed or archived topic/,
      )
    end

    it "raises when topic does not exist" do
      expect do
        execute_node(
          configuration: {
            "topic_id" => "-1",
            "raw" => "Workflow reply",
          },
          item: {
            "json" => {
            },
          },
        )
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

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
          DiscourseWorkflows::NodeExecutionContext.new(
            input_items: [{ "json" => { "name" => "Ada" } }],
            node_context: {
            },
            resolver:
              DiscourseWorkflows::ExpressionResolver.new(
                {
                  "$json" => {
                    "name" => "Ada",
                  },
                  "trigger" => {
                    "topic_id" => topic.id,
                    "reply_to_post_number" => first_post.post_number,
                    "user_id" => admin.id,
                  },
                },
              ),
          ),
        )[
          0
        ]

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
