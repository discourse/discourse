# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicCategory::V1 do
  fab!(:admin)
  fab!(:category)
  fab!(:topic, :topic_with_op)

  it "records the move without moving" do
    configuration = {
      "topic_id" => topic.id,
      "category_id" => category.id,
      "actor_username" => admin.username,
    }
    effects = nil

    output = simulate_node_output(configuration:) { |state| effects = state.effects }

    expect(effects.first).to include(
      "type" => "topic_category_changed",
      "fields" => {
        "topic_id" => topic.id,
        "category_id" => category.id,
      },
    )
    expect(output.first.first["json"]).to include("category_id" => category.id)
    expect(topic.reload.category_id).not_to eq(category.id)
  end
end
