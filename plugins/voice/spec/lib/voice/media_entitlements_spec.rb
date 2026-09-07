# frozen_string_literal: true

RSpec.describe Voice::MediaEntitlements do
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:low_trust_user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before { SiteSetting.voice_enabled = true }

  it "answers each capability per user in one pass" do
    SiteSetting.voice_video_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
    SiteSetting.voice_screen_share_allowed_groups = Group::AUTO_GROUPS[:logged_in_users]

    entitlements = described_class.for_users(room, [member, low_trust_user])

    expect(entitlements[member.id]).to eq(can_publish_video: true, can_screen_share: true)
    expect(entitlements[low_trust_user.id]).to eq(can_publish_video: false, can_screen_share: true)
  end

  it "denies everything when the room has media disabled" do
    room.update!(video_enabled: false)

    expect(described_class.for_users(room, [member])[member.id]).to eq(described_class::NONE)
  end

  it "denies everything when a capability has no groups" do
    SiteSetting.voice_video_allowed_groups = ""
    SiteSetting.voice_screen_share_allowed_groups = ""

    expect(described_class.for_users(room, [member])[member.id]).to eq(described_class::NONE)
  end

  it "resolves a group list of real groups without the pseudogroup shortcut" do
    group = Fabricate(:group)
    group.add(member)
    SiteSetting.voice_video_allowed_groups = group.id.to_s
    SiteSetting.voice_screen_share_allowed_groups = group.id.to_s

    entitlements = described_class.for_users(room, [member, low_trust_user])

    expect(entitlements[member.id]).to eq(can_publish_video: true, can_screen_share: true)
    expect(entitlements[low_trust_user.id]).to eq(described_class::NONE)
  end

  it "reads a whole roster without querying per user" do
    users = Array.new(3) { Fabricate(:user) }
    SiteSetting.voice_video_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.voice_screen_share_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]

    queries = track_sql_queries { described_class.for_users(room, users) }

    expect(queries.count { |sql| sql.include?("group_users") }).to eq(2)
  end
end
