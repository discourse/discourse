# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserInGroup::V1 do
  fab!(:group)
  fab!(:member, :user)
  fab!(:non_member, :user)

  before { group.add(member) }

  describe "#execute" do
    it "keeps items for users in the configured group", :aggregate_failures do
      output =
        execute_node_output(
          configuration: {
            "username" => "={{ $json.username }}",
            "group_id" => group.id,
            "actor_username" => "system",
          },
          input_items: [
            { "json" => { "username" => member.username, "post_id" => 1 } },
            { "json" => { "username" => non_member.username, "post_id" => 2 } },
          ],
        )

      expect(output.first.map { |item| item["json"] }).to contain_exactly(
        include("username" => member.username, "post_id" => 1),
      )
      expect(output.second.map { |item| item["json"] }).to contain_exactly(
        include("username" => non_member.username, "post_id" => 2),
      )
    end

    it "raises when the user cannot be found" do
      expect do
        execute_node(configuration: { "username" => "missing_user", "group_id" => group.id })
      end.to raise_error(DiscourseWorkflows::NodeError, "User 'missing_user' not found")
    end
  end
end
