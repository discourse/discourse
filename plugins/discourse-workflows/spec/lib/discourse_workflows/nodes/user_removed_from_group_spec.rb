# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserRemovedFromGroup::V1 do
  fab!(:admin)
  fab!(:user)
  fab!(:group)

  before { group.add(user) }

  it "outputs a null actor when the caller didn't say who acted", :aggregate_failures do
    event = DiscourseEvent.track(:user_removed_from_group) { group.remove(user) }
    output = described_class.new(*event[:params]).output

    expect(output[:user]).to include(id: user.id, username: user.username)
    expect(output[:group]).to include(id: group.id, name: group.name)
    expect(output[:membership]).to eq(action: "removed", automatic: nil)
    expect(output[:actor]).to be_nil
    expect(output).to match_node_output_schema(described_class)
  end

  it "outputs the user who removed the member", :aggregate_failures do
    event =
      DiscourseEvent.track(:user_removed_from_group) do
        GroupMemberRemover.remove(admin.guardian, group, usernames: user.username)
      end
    output = described_class.new(*event[:params]).output

    expect(output[:actor]).to include(id: admin.id, username: admin.username)
    expect(output).to match_node_output_schema(described_class)
  end
end
