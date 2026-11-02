# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Assigned::V2 do
  fab!(:topic)
  fab!(:assigned_by_user, :admin)
  fab!(:assignee, :moderator)

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.enable_discourse_workflows = true
    Fabricate(:post, topic:)
  end

  it "returns the assigner as actor and assigned_by", :aggregate_failures do
    event =
      DiscourseEvent.track(:assigned) { Assigner.new(topic, assigned_by_user).assign(assignee) }
    output = described_class.from_event(:assigned, *event[:params]).output

    expect(output[:actor][:username]).to eq(assigned_by_user.username)
    expect(output[:assignment][:assigned_by][:username]).to eq(assigned_by_user.username)
    expect(output[:assignment]).not_to have_key(:assigned_by_user)
    expect(output).to match_node_output_schema(described_class)
  end
end
