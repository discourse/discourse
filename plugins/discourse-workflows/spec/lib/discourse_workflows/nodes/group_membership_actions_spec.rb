# frozen_string_literal: true

RSpec.shared_context "with a group to manage" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:group)
  fab!(:owner) { Fabricate(:user).tap { |owner| group.add_owner(owner) } }

  def run_node(username: user.username, group_id: group.id, actor_username: admin.username, **rest)
    execute_node(
      configuration: {
        "username" => username,
        "group_id" => group_id,
        "actor_username" => actor_username,
        **rest.stringify_keys,
      },
    )
  end

  def membership_error(key, **args)
    node_error_message(key, scope: "group_membership_action", item_index: 0, **args)
  end

  def group_logs(action)
    GroupHistory.where(group:, target_user: user, action: GroupHistory.actions[action])
  end
end

RSpec.shared_examples "a group membership action" do |not_allowed:|
  it "refuses actors who can't edit the group, even when nothing would change",
     :aggregate_failures do
    expect { run_node(actor_username: user.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      membership_error(not_allowed, username: user.username, group: group.name),
    )
    expect { run_node(actor_username: moderator.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      membership_error(not_allowed, username: moderator.username, group: group.name),
    )
  end

  it "lets moderators allowed to manage groups change members" do
    SiteSetting.moderators_manage_groups = true

    expect { run_node(actor_username: moderator.username) }.not_to raise_error
  end

  it "refuses automatic groups" do
    trust_level_group = Group.find(Group::AUTO_GROUPS[:trust_level_1])

    expect { run_node(group_id: trust_level_group.id) }.to raise_error(
      DiscourseWorkflows::NodeError,
      membership_error("automatic_group", group: trust_level_group.name),
    )
  end

  it "fails on a missing group" do
    expect { run_node(group_id: -42) }.to raise_error(
      DiscourseWorkflows::NodeError,
      membership_error("group_not_found", group_id: -42),
    )
  end

  it "offers only groups whose members can change", :aggregate_failures do
    context =
      DiscourseWorkflows::LoadOptionsContext.new(
        method_name: "groups",
        parameters: {
        },
        filter: nil,
        node_class: described_class,
      )
    options = described_class.load_options_context(context)

    expect(options).to include({ id: group.id, name: group.name })
    expect(options.map { it[:id] }).not_to include(*Group::AUTO_GROUPS.values)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::AddUserToGroup::V1 do
  include_context "with a group to manage"

  it_behaves_like "a group membership action", not_allowed: "add_not_allowed"

  it "adds the user as the actor", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:user_added_to_group) { result = run_node }

    expect(result).to include(
      "user" => include("id" => user.id),
      "group" => include("id" => group.id, "user_count" => group.reload.user_count),
      "actor" => include("id" => admin.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(group.users).to include(user)
    expect(group_logs(:add_user_to_group).sole.acting_user).to eq(admin)
    expect(events.sole[:params]).to eq([user, group, { automatic: false, acting_user: admin }])
  end

  it "lets group owners add members" do
    expect(run_node(actor_username: owner.username)).to include("changed" => true)
  end

  it "reports nothing changed for a member, without logging it", :aggregate_failures do
    group.add(user)

    expect(run_node).to include("changed" => false)
    expect(group_logs(:add_user_to_group)).to be_empty
  end

  it "reports nothing changed when a concurrent request added the user first" do
    GroupMemberAdder.stubs(:add).raises(GroupMemberAdder::AlreadyMembers.new([user.username]))

    expect(run_node).to include("changed" => false)
  end

  it "outputs the trust level the group grants, after the trust level groups' own events",
     :aggregate_failures do
    user.update!(trust_level: TrustLevel[0])
    group.update!(grant_trust_level: TrustLevel[2])
    trust_level_group = Group.find(Group::AUTO_GROUPS[:trust_level_2])

    result = nil
    events = DiscourseEvent.track_events(:user_added_to_group) { result = run_node }
    groups_and_payloads = events.map { it[:params].drop(1) }

    expect(result).to include("user" => include("trust_level" => TrustLevel[2]))
    expect(groups_and_payloads).to include(
      [trust_level_group, { automatic: true, acting_user: Discourse.system_user }],
    )
    expect(groups_and_payloads.last).to eq([group, { automatic: false, acting_user: admin }])
  end

  it "sends the user a message only when asked", :aggregate_failures do
    expect_not_enqueued_with(job: :notify_users_added_to_group) { run_node }

    group.remove(user)

    expect_enqueued_with(
      job: :notify_users_added_to_group,
      args: {
        user_ids: [user.id],
        group_id: group.id,
      },
    ) { run_node(notify_user: true) }
  end

  context "with set_primary_group" do
    it "makes the group the user's primary group" do
      run_node(set_primary_group: true)

      expect(user.reload.primary_group).to eq(group)
    end

    it "reports a change for a member whose primary group it wasn't", :aggregate_failures do
      group.add(user)

      expect(run_node(set_primary_group: true)).to include("changed" => true)
      expect(run_node(set_primary_group: true)).to include("changed" => false)
    end
  end
end

RSpec.describe DiscourseWorkflows::Nodes::RemoveUserFromGroup::V1 do
  include_context "with a group to manage"

  before { group.add(user) }

  it_behaves_like "a group membership action", not_allowed: "remove_not_allowed"

  it "removes the user as the actor", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:user_removed_from_group) { result = run_node }

    expect(result).to include(
      "user" => include("id" => user.id),
      "group" => include("id" => group.id),
      "actor" => include("id" => admin.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(group.users).not_to include(user)
    expect(group_logs(:remove_user_from_group).sole.acting_user).to eq(admin)
    expect(events.sole[:params]).to eq([user, group, { acting_user: admin }])
  end

  it "removes owners too" do
    run_node(username: owner.username, actor_username: owner.username)

    expect(group.users).not_to include(owner)
  end

  it "reports nothing changed for a non-member, without logging it", :aggregate_failures do
    group.remove(user)

    expect(run_node).to include("changed" => false)
    expect(group_logs(:remove_user_from_group)).to be_empty
  end

  it "reports nothing changed when a concurrent request added the user back" do
    GroupMemberRemover.stubs(:remove).raises(Discourse::InvalidParameters)

    expect(run_node).to include("changed" => false)
  end
end
