# frozen_string_literal: true

describe Jobs::PublishGroupMembershipUpdates do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }

  it "publishes events for added users" do
    events =
      DiscourseEvent.track_events do
        subject.execute(user_ids: [user.id], group_id: group.id, type: "add")
      end

    expect(events).to include(
      event_name: :user_added_to_group,
      params: [user, group, { automatic: group.automatic }],
    )
  end

  it "publishes events for removed users" do
    events =
      DiscourseEvent.track_events do
        subject.execute(user_ids: [user.id], group_id: group.id, type: "remove")
      end

    expect(events).to include(event_name: :user_removed_from_group, params: [user, group])
  end

  it "does nothing if the group doesn't exist" do
    events =
      DiscourseEvent.track_events do
        subject.execute(user_ids: [user.id], group_id: nil, type: "add")
      end

    expect(events).not_to include(
      event_name: :user_added_to_group,
      params: [user, group, { automatic: group.automatic }],
    )
  end

  it "fails when the update type is invalid" do
    expect { subject.execute(user_ids: [user.id], group_id: nil, type: nil) }.to raise_error(
      Discourse::InvalidParameters,
    )
  end

  it "does nothing when the user is not human" do
    events =
      DiscourseEvent.track_events do
        subject.execute(user_ids: [Discourse.system_user.id], group_id: nil, type: "add")
      end

    expect(events).not_to include(
      event_name: :user_added_to_group,
      params: [user, group, { automatic: group.automatic }],
    )
  end
end
