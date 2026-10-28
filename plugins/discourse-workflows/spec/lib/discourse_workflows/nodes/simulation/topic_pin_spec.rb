# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicPin::V1 do
  fab!(:admin)
  fab!(:topic, :topic_with_op)

  it "records a pin and reports the topic as pinned without pinning" do
    configuration = {
      "operation" => "add",
      "pin_type" => "pin",
      "topic_id" => topic.id,
      "actor_username" => admin.username,
    }
    effects = nil

    output = simulate_node_output(configuration:) { |state| effects = state.effects }

    expect(effects.first).to include(
      "type" => "topic_pinned",
      "fields" => {
        "topic_id" => topic.id,
      },
    )
    expect(output.first.first["json"]["pinned"]).to be(true)
    expect(topic.reload.pinned_at).to be_nil
  end
end
