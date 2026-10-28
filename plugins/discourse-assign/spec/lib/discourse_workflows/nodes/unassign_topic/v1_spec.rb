# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UnassignTopic::V1 do
  fab!(:moderator)
  fab!(:user, :moderator)
  fab!(:post)
  fab!(:topic) { post.topic }

  before do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.assign_enabled = true
  end

  def unassign(actor_username: moderator.username, **rest)
    execute_node(
      configuration: {
        "topic_id" => topic.id.to_s,
        "actor_username" => actor_username,
        **rest.stringify_keys,
      },
    )
  end

  it "unassigns the topic as the actor", :aggregate_failures do
    Assigner.new(topic, moderator).assign(user)

    result = nil
    events = DiscourseEvent.track_events(:unassigned) { result = unassign }

    expect(result).to include(
      "previously_assigned" => include("type" => "user", "user" => include("id" => user.id)),
      "actor" => include("id" => moderator.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(Assignment.where(target: topic)).to be_empty
    expect(events.sole[:params].last).to include(acting_user: moderator)
  end

  it "unassigns a post" do
    Assigner.new(post, moderator).assign(user)

    expect(unassign(resource: "post", post_id: post.id.to_s)).to include("changed" => true)
    expect(Assignment.where(target: post)).to be_empty
  end

  it "reports nothing changed when a concurrent request unassigned it first", :aggregate_failures do
    Assigner.new(topic, moderator).assign(user)
    Assignment.any_instance.stubs(:lock!).raises(ActiveRecord::RecordNotFound)

    events =
      DiscourseEvent.track_events(:unassigned) { expect(unassign).to include("changed" => false) }

    expect(events).to be_empty
  end

  it "reports nothing changed when nothing is assigned" do
    expect(unassign).to include("changed" => false, "previously_assigned" => include("type" => nil))
  end

  it "refuses actors who can't assign, even when nothing would change" do
    regular_user = Fabricate(:user)

    expect { unassign(actor_username: regular_user.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      "#{I18n.t("discourse_assign.discourse_workflows.assignment_action.not_allowed", username: regular_user.username)} [item 0]",
    )
  end
end
