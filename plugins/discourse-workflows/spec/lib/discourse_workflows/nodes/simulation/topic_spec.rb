# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Topic::V1 do
  fab!(:admin)
  fab!(:category)
  fab!(:topic, :topic_with_op)

  it "records a topic creation and returns synthetic topic and post" do
    configuration = {
      "operation" => "create",
      "title" => "A simulated topic title",
      "raw" => "This body is long enough to pass validation.",
      "category_id" => category.id,
      "actor_username" => admin.username,
    }
    effects = nil
    output = nil

    expect {
      output = simulate_node_output(configuration:) { |state| effects = state.effects }
    }.not_to change { Topic.count }

    expect(effects.first).to include(
      "type" => "topic_created",
      "fields" => {
        "title" => "A simulated topic title",
        "category_id" => category.id,
        "raw" => "This body is long enough to pass validation.",
      },
    )
    json = output.first.first["json"]
    expect(json["topic"]["id"]).to be_negative
    expect(json["post_id"]).to be_negative
    expect(json["__synthetic"]).to be(true)
  end

  it "records a close and returns the topic as closed without closing it" do
    configuration = {
      "operation" => "close",
      "topic_id" => topic.id,
      "actor_username" => admin.username,
    }
    effects = nil

    output = simulate_node_output(configuration:) { |state| effects = state.effects }

    expect(effects.first).to include(
      "type" => "topic_closed",
      "fields" => {
        "topic_id" => topic.id,
      },
    )
    expect(output.first.first["json"]["topic"]["closed"]).to be(true)
    expect(topic.reload.closed).to be(false)
  end

  it "records a bump without bumping" do
    configuration = {
      "operation" => "bump",
      "topic_id" => topic.id,
      "actor_username" => admin.username,
    }
    effects = nil

    expect {
      simulate_node_output(configuration:) { |state| effects = state.effects }
    }.not_to change { topic.reload.bumped_at }

    expect(effects.first).to include("type" => "topic_bumped")
  end

  it "runs a get for real" do
    configuration = {
      "operation" => "get",
      "topic_id" => topic.id,
      "actor_username" => admin.username,
    }

    output = simulate_node_output(configuration:)

    expect(output.first.first["json"]["topic"]["id"]).to eq(topic.id)
  end
end
