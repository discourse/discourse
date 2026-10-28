# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SendPersonalMessage::V1 do
  fab!(:recipient, :user)
  fab!(:sender, :admin)

  let(:configuration) do
    {
      "recipient_usernames" => [recipient.username],
      "title" => "Welcome aboard",
      "raw" => "Glad to have you here, **friend**.",
      "sender_username" => sender.username,
    }
  end

  it "records the message instead of sending it" do
    effects = nil
    outputs =
      expect {
        simulate_node_output(configuration:) { |state| effects = state.effects }
      }.not_to change { Post.count }

    expect(effects).to contain_exactly(
      a_hash_including(
        "type" => "personal_message",
        "fields" => {
          "recipient" => recipient.username,
          "title" => "Welcome aboard",
          "body" => "Glad to have you here, **friend**.",
        },
        "step" => "Step under test",
        "item_index" => 0,
      ),
    )
  end

  it "returns the same output shape as a real send, with synthetic ids" do
    real = execute_node(configuration:)
    simulated = simulate_node_output(configuration:).first.first["json"]

    expect(simulated["topic"].keys).to match_array(real["topic"].keys)
    expect(simulated["post"].keys).to match_array(real["post"].keys)
    expect(simulated["topic"]["id"]).to be_negative
    expect(simulated["post"]["id"]).to be_negative
    expect(simulated["post"]["cooked"]).to include("<strong>friend</strong>")
    expect(simulated["__synthetic"]).to be(true)
  end

  it "still rejects a message with no recipients" do
    expect {
      simulate_node_output(configuration: configuration.merge("recipient_usernames" => []))
    }.to raise_error(DiscourseWorkflows::NodeError)
  end

  it "still rejects an unknown recipient" do
    expect {
      simulate_node_output(configuration: configuration.merge("recipient_usernames" => ["nobody"]))
    }.to raise_error(DiscourseWorkflows::NodeError)
  end
end
