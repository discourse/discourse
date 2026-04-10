# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::CreateTopic::V1 do
  fab!(:admin)
  fab!(:category)

  before { SiteSetting.tagging_enabled = true }

  def execute_node(configuration:, item:, run_as_user: Discourse.system_user)
    action = described_class.new(configuration: configuration)
    input_items = [item]
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => item.fetch("json") { {} } })
    exec_ctx =
      DiscourseWorkflows::NodeExecutionContext.new(
        input_items: input_items,
        run_as_user: run_as_user,
        resolver: resolver,
        configuration: configuration,
        configuration_schema: described_class.configuration_schema,
      )
    items = action.execute(exec_ctx)[0]
    items.first["json"]
  end

  describe "#execute" do
    let(:item) { { "json" => {} } }

    it "creates a topic for the configured user" do
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "title" => "Workflow topic",
              "raw" => "First post body",
              "category_id" => category.id.to_s,
              "user_id" => admin.id.to_s,
            },
            item: item,
          )
      end.to change(Topic, :count).by(1).and change(Post, :count).by(1)

      topic = Topic.last

      expect(topic.title).to eq("Workflow topic")
      expect(topic.first_post.raw).to eq("First post body")
      expect(topic.category_id).to eq(category.id)
      expect(topic.user_id).to eq(admin.id)

      expect(result["topic"]).to include(
        "id" => topic.id,
        "title" => topic.title,
        "raw" => "First post body",
        "category_id" => category.id,
        "user_id" => admin.id,
        "username" => admin.username,
        "archetype" => Archetype.default,
      )
      expect(result).to include("post_id" => topic.first_post.id, "post_number" => 1)
    end

    it "falls back to the system user when no user is configured" do
      execute_node(
        configuration: {
          "title" => "System topic",
          "raw" => "Created by workflows",
        },
        item: item,
      )

      expect(Topic.last.user_id).to eq(Discourse.system_user.id)
    end

    it "accepts tags from an array" do
      execute_node(
        configuration: {
          "title" => "Tagged topic",
          "raw" => "With tags",
          "tag_names" => ["alpha", " beta "],
        },
        item: item,
      )

      expect(Topic.last.tags.pluck(:name)).to contain_exactly("alpha", "beta")
    end

    it "raises when the user cannot be found" do
      expect do
        execute_node(
          configuration: {
            "title" => "Workflow topic",
            "raw" => "First post body",
            "user_id" => -999,
          },
          item: item,
        )
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises when topic creation fails validation" do
      expect do
        execute_node(configuration: { "title" => "", "raw" => "" }, item: item)
      end.to raise_error(RuntimeError)
    end
  end
end
