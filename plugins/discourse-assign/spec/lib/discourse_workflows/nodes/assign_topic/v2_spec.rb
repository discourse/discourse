# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::AssignTopic::V2 do
  fab!(:moderator)
  fab!(:user, :moderator)
  fab!(:topic)

  before do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.assign_enabled = true
  end

  def assign(assignee: user.username, actor_username: moderator.username, **rest)
    execute_node(
      configuration: {
        "topic_id" => topic.id.to_s,
        "assignee" => assignee,
        "actor_username" => actor_username,
        **rest.stringify_keys,
      },
    )
  end

  it "assigns the topic as the actor", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:assigned) { result = assign }

    expect(result).to include(
      "assignee" => include("type" => "user", "user" => include("id" => user.id)),
      "previously_assigned" => include("type" => nil),
      "actor" => include("id" => moderator.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(Assignment.find_by(target: topic).assigned_by_user).to eq(moderator)
    expect(events.sole[:params].last).to include(acting_user: moderator)
  end

  it "reports nothing changed when the assignee is already assigned", :aggregate_failures do
    Assigner.new(topic, moderator).assign(user)

    events =
      DiscourseEvent.track_events(:assigned) { expect(assign).to include("changed" => false) }

    expect(events).to be_empty
  end

  it "replaces another assignee" do
    other_user = Fabricate(:moderator)
    Assigner.new(topic, moderator).assign(other_user)

    expect(assign).to include(
      "previously_assigned" => include("user" => include("id" => other_user.id)),
      "changed" => true,
    )
  end

  it "refuses actors who can't assign, even when nothing would change" do
    regular_user = Fabricate(:user)

    expect { assign(actor_username: regular_user.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      "#{I18n.t("discourse_assign.discourse_workflows.assignment_action.not_allowed", username: regular_user.username)} [item 0]",
    )
  end

  it "fails when the assignee can't be assigned" do
    regular_user = Fabricate(:user)

    expect { assign(assignee: regular_user.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(I18n.t("discourse_assign.discourse_workflows.assign_topic.error", reason: ""))}/,
    )
  end
end
