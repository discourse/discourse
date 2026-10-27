# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserAddedToGroup::V1 do
  fab!(:admin)
  fab!(:user)
  fab!(:group)

  it "outputs a null actor when the caller didn't say who acted", :aggregate_failures do
    event = DiscourseEvent.track(:user_added_to_group) { group.add(user) }
    output = described_class.new(*event[:params]).output

    expect(output[:user]).to include(id: user.id, username: user.username)
    expect(output[:group]).to include(id: group.id, name: group.name)
    expect(output[:membership]).to eq(action: "added", automatic: false)
    expect(output[:actor]).to be_nil
    expect(output).to match_node_output_schema(described_class)
  end

  it "outputs the user who added the member", :aggregate_failures do
    event = DiscourseEvent.track(:user_added_to_group) { group.add(user, acting_user: admin) }
    output = described_class.new(*event[:params]).output

    expect(output[:actor]).to include(id: admin.id, username: admin.username)
    expect(output).to match_node_output_schema(described_class)
  end

  it "outputs the system user for an automatic membership", :aggregate_failures do
    event =
      DiscourseEvent.track(:user_added_to_group) do
        Group.user_trust_level_change!(user.id, TrustLevel[3])
      end
    output = described_class.new(*event[:params]).output

    expect(output[:membership]).to eq(action: "added", automatic: true)
    expect(output[:actor]).to include(id: Discourse.system_user.id)
  end
end
