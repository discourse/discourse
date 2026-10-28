# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Badge::V1 do
  fab!(:user)
  fab!(:admin)
  fab!(:badge)

  let(:configuration) do
    {
      "operation" => "grant",
      "username" => user.username,
      "badge_id" => badge.id,
      "actor_username" => admin.username,
    }
  end

  it "records the grant without granting" do
    effects = nil

    expect {
      simulate_node_output(configuration:) { |state| effects = state.effects }
    }.not_to change { UserBadge.count }

    expect(effects).to contain_exactly(
      a_hash_including(
        "type" => "badge_granted",
        "fields" => {
          "username" => user.username,
          "badge_id" => badge.id,
        },
      ),
    )
  end

  it "records a revoke for the revoke operation" do
    BadgeGranter.grant(badge, user)
    effects = nil

    expect {
      simulate_node_output(configuration: configuration.merge("operation" => "revoke")) do |state|
        effects = state.effects
      end
    }.not_to change { UserBadge.count }

    expect(effects.first["type"]).to eq("badge_revoked")
  end

  it "returns the same output as the real grant" do
    simulated = simulate_node_output(configuration:).first.first["json"]
    real = execute_node(configuration:)

    expect(simulated).to eq(real)
  end

  it "still enforces the actor's permission" do
    expect {
      simulate_node_output(configuration: configuration.merge("actor_username" => user.username))
    }.to raise_error(Discourse::InvalidAccess)
  end
end
