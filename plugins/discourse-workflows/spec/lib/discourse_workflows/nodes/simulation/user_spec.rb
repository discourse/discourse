# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::User::V1 do
  fab!(:user)
  fab!(:admin)

  it "reads a user for real and skips the email staff log" do
    configuration = {
      "operation" => "get",
      "username" => user.username,
      "include_extensions" => ["emails"],
      "actor_username" => admin.username,
    }

    output = nil
    expect { output = simulate_node_output(configuration:) }.not_to change { UserHistory.count }

    expect(output.first.first["json"]["user"]["email"]).to eq(user.email)
  end

  it "records an edit without applying it" do
    configuration = {
      "operation" => "edit",
      "username" => user.username,
      "updates" => {
        "title" => "Helper",
      },
      "actor_username" => admin.username,
    }
    effects = nil

    simulate_node_output(configuration:) { |state| effects = state.effects }

    expect(effects.first).to include(
      "type" => "user_updated",
      "fields" => {
        "username" => user.username,
      },
    )
    expect(user.reload.title).to be_nil
  end
end
