# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Group::V1 do
  fab!(:user)
  fab!(:admin)
  fab!(:group)

  let(:configuration) do
    {
      "operation" => "add",
      "username" => user.username,
      "group_id" => group.id,
      "actor_username" => admin.username,
    }
  end

  it "records the membership change without applying it" do
    effects = nil

    expect {
      simulate_node_output(configuration:) { |state| effects = state.effects }
    }.not_to change { GroupUser.count }

    expect(effects).to contain_exactly(
      a_hash_including(
        "type" => "group_member_added",
        "fields" => {
          "username" => user.username,
          "group_id" => group.id,
        },
      ),
    )
  end

  it "marks the group as touched so a later read of it blocks" do
    simulate_node_output(configuration:) do |state, ctx|
      expect(state.touched?(:group, group.id)).to be(true)
      expect { ctx.read_record(:group, group.id) }.to raise_error(
        DiscourseWorkflows::Simulation::SafetyError,
      ) { |error| expect(error.reason_key).to eq("touched_record") }
    end
  end

  it "runs the membership check for real, read-only" do
    group.add(user)
    output =
      simulate_node_output(configuration: configuration.merge("operation" => "check_membership"))

    expect(output.first.first["json"]["group_membership"]).to include("in_group" => true)
  end

  it "returns the same output as a real add" do
    simulated = simulate_node_output(configuration:).first.first["json"]
    real = execute_node(configuration:)

    expect(simulated.keys).to match_array(real.keys)
    expect(simulated["group"]["id"]).to eq(group.id)
    expect(simulated["user"]["username"]).to eq(user.username)
  end

  it "still enforces the actor's permission" do
    expect {
      simulate_node_output(configuration: configuration.merge("actor_username" => user.username))
    }.to raise_error(Discourse::InvalidAccess)
  end
end
