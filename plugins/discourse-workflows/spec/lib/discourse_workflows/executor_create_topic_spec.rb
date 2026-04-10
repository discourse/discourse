# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:admin)
  fab!(:category)

  before { SiteSetting.tagging_enabled = true }

  describe "#run" do
    it "creates a topic from trigger data" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "action-1",
                 "action:create_topic",
                 name: "Create Topic",
                 configuration: {
                   "title" => "={{ trigger.title }}",
                   "raw" => "={{ trigger.raw }}",
                   "category_id" => "={{ trigger.category_id }}",
                   "tag_names" => "={{ trigger.tags }}",
                   "user_id" => "={{ trigger.user_id }}",
                 }
          g.chain "trigger-1", "action-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true, **graph)

      trigger_data = {
        title: "Created from workflow",
        raw: "Generated body",
        category_id: category.id,
        tags: %w[alpha beta],
        user_id: admin.id,
      }

      execution = described_class.new(workflow, "trigger-1", trigger_data).run
      topic = Topic.last

      expect(execution.status).to eq("success")
      expect(topic.title).to eq("Created from workflow")
      expect(topic.first_post.raw).to eq("Generated body")
      expect(topic.category_id).to eq(category.id)
      expect(topic.user_id).to eq(admin.id)
      expect(topic.tags.pluck(:name)).to contain_exactly("alpha", "beta")
      expect(execution.execution_data.context_data["Create Topic"].first["json"]).to include(
        "topic" =>
          include(
            "id" => topic.id,
            "title" => topic.title,
            "raw" => "Generated body",
            "user_id" => admin.id,
          ),
        "post_id" => topic.first_post.id,
        "post_number" => topic.first_post.post_number,
      )
    end
  end
end
