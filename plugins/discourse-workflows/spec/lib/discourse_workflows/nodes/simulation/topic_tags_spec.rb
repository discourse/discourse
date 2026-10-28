# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicTags::V2 do
  fab!(:admin)
  fab!(:topic, :topic_with_op)
  fab!(:tag) { Fabricate(:tag, name: "needs-review") }

  before { SiteSetting.tagging_enabled = true }

  it "records the resulting tag set without tagging" do
    configuration = {
      "mode" => "modify",
      "topic_id" => topic.id,
      "add_tag_names" => "needs-review",
      "actor_username" => admin.username,
    }
    effects = nil

    output = simulate_node_output(configuration:) { |state| effects = state.effects }

    expect(effects.first).to include(
      "type" => "topic_tagged",
      "fields" => {
        "topic_id" => topic.id,
        "tags" => ["needs-review"],
      },
    )
    expect(output.first.first["json"]["tag_names"]).to eq(["needs-review"])
    expect(topic.reload.tags).to be_empty
  end
end

RSpec.describe DiscourseWorkflows::Nodes::TopicTags::V1 do
  fab!(:admin)
  fab!(:topic, :topic_with_op)
  fab!(:tag) { Fabricate(:tag, name: "needs-review") }

  before { SiteSetting.tagging_enabled = true }

  it "records an add without tagging" do
    configuration = {
      "operation" => "add",
      "topic_id" => topic.id,
      "tag_names" => "needs-review",
      "actor_username" => admin.username,
    }
    effects = nil

    simulate_node_output(configuration:) { |state| effects = state.effects }

    expect(effects.first).to include("type" => "topic_tagged")
    expect(topic.reload.tags).to be_empty
  end
end
