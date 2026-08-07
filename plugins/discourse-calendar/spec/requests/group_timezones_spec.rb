# frozen_string_literal: true

describe "group timezones serialization" do
  fab!(:non_member, :user)
  fab!(:member, :user)
  fab!(:staff, :moderator)
  fab!(:admin)
  fab!(:public_group_user) { Fabricate(:user, username: "public_roster_user") }
  fab!(:members_group_user) { Fabricate(:user, username: "members_roster_user") }
  fab!(:hidden_group_user) { Fabricate(:user, username: "hidden_roster_user") }

  fab!(:public_group) do
    Fabricate(
      :group,
      name: "timezone-public",
      visibility_level: Group.visibility_levels[:public],
      members_visibility_level: Group.visibility_levels[:public],
    )
  end

  fab!(:members_group) do
    Fabricate(
      :group,
      name: "timezone-members",
      visibility_level: Group.visibility_levels[:public],
      members_visibility_level: Group.visibility_levels[:members],
    )
  end

  fab!(:hidden_group) do
    Fabricate(
      :group,
      name: "timezone-hidden",
      visibility_level: Group.visibility_levels[:owners],
      members_visibility_level: Group.visibility_levels[:public],
    )
  end

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true

    public_group.add(public_group_user)
    members_group.add(member)
    members_group.add(members_group_user)
    hidden_group.add(hidden_group_user)
  end

  it "serializes only groups with visible membership for each viewer" do
    [public_group_user, members_group_user, hidden_group_user].each do |group_user|
      group_user.user_option.update!(timezone: "America/New_York")
    end

    timezones_post = create_post(raw: <<~RAW)
          [timezones group="timezone-public"]
          [/timezones]

          [timezones group="timezone-members"]
          [/timezones]

          [timezones group="timezone-hidden"]
          [/timezones]
        RAW

    expect(timezones_post.reload.group_timezones).to eq(
      "groups" => [public_group.name, members_group.name, hidden_group.name],
    )

    cases = [
      { viewer: nil, visible_groups: [public_group.name] },
      { viewer: non_member, visible_groups: [public_group.name] },
      { viewer: member, visible_groups: [public_group.name, members_group.name] },
      { viewer: staff, visible_groups: [public_group.name, members_group.name] },
      { viewer: admin, visible_groups: [public_group.name, members_group.name, hidden_group.name] },
    ]

    cases.each do |test_case|
      viewer = test_case[:viewer]
      visible_groups = test_case[:visible_groups]

      sign_in(viewer) if viewer

      get "/t/#{timezones_post.topic.slug}/#{timezones_post.topic.id}.json"

      expect(response.status).to eq(200)
      group_timezones = response.parsed_body.dig("post_stream", "posts", 0, "group_timezones")
      expect(group_timezones.keys).to contain_exactly(*visible_groups)

      expect(response.body).to include(public_group_user.username)

      if visible_groups.exclude?(hidden_group.name)
        expect(response.body).not_to include(hidden_group_user.username)
      end
    end
  end
end
