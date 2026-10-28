# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Post::V1 do
  fab!(:admin)
  fab!(:topic, :topic_with_op)

  it "records a reply without creating it and returns a synthetic post in the topic" do
    configuration = {
      "operation" => "create",
      "topic_id" => topic.id,
      "raw" => "Simulated reply",
      "author_username" => admin.username,
    }
    effects = nil

    output = nil
    expect {
      output = simulate_node_output(configuration:) { |state| effects = state.effects }
    }.not_to change { Post.count }

    expect(effects).to contain_exactly(
      a_hash_including(
        "type" => "post_created",
        "fields" => {
          "topic_id" => topic.id,
          "raw" => "Simulated reply",
        },
      ),
    )
    post = output.first.first["json"]["post"]
    expect(post["id"]).to be_negative
    expect(post["topic_id"]).to eq(topic.id)
    expect(post["post_number"]).to eq(topic.highest_post_number + 1)
  end

  it "still enforces the closed-topic rule" do
    topic.update!(closed: true)
    configuration = {
      "operation" => "create",
      "topic_id" => topic.id,
      "raw" => "Simulated reply",
      "author_username" => admin.username,
    }

    expect { simulate_node_output(configuration:) }.to raise_error(DiscourseWorkflows::NodeError)
  end

  it "records an edit and returns the edited content without saving" do
    post = topic.first_post
    configuration = {
      "operation" => "edit",
      "post_id" => post.id,
      "raw" => "Edited in a simulation",
      "editor_username" => admin.username,
    }
    effects = nil

    output = simulate_node_output(configuration:) { |state| effects = state.effects }

    expect(effects.first).to include("type" => "post_edited")
    expect(output.first.first["json"]["post"]["raw"]).to eq("Edited in a simulation")
    expect(post.reload.raw).not_to eq("Edited in a simulation")
  end

  it "records a delete without deleting" do
    post = Fabricate(:post, topic:)
    configuration = {
      "operation" => "delete",
      "post_id" => post.id,
      "actor_username" => admin.username,
    }
    effects = nil

    simulate_node_output(configuration:) { |state| effects = state.effects }

    expect(effects.first).to include("type" => "post_deleted")
    expect(post.reload.deleted_at).to be_nil
  end

  it "runs a get for real, read-only, and blocks when the post was touched earlier" do
    post = topic.first_post
    configuration = {
      "operation" => "get",
      "post_id" => post.id,
      "actor_username" => admin.username,
    }

    output = simulate_node_output(configuration:)
    expect(output.first.first["json"]["post"]["id"]).to eq(post.id)

    expect {
      simulate_node_output(configuration:) { |state, _ctx| state.touch(:post, post.id) }
    }.not_to raise_error
  end

  it "blocks a get of a post an earlier step would have changed" do
    post = topic.first_post
    items = [{ "json" => { "op" => "edit" } }, { "json" => { "op" => "get" } }]
    configuration = {
      "operation" => "={{ $json.op }}",
      "post_id" => post.id,
      "raw" => "touch",
      "editor_username" => admin.username,
      "actor_username" => admin.username,
    }

    expect { simulate_node_output(configuration:, input_items: items) }.to raise_error(
      DiscourseWorkflows::Simulation::SafetyError,
    ) { |error| expect(error.reason_key).to eq("touched_record") }
  end
end
