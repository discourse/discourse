# frozen_string_literal: true

RSpec.describe Live::FileTransferEntitlements do
  fab!(:user)
  fab!(:other_user, :user)

  before { SiteSetting.live_enabled = true }

  it "uses the direct-call group setting shape, empty default and refresh without client group ids" do
    settings = YAML.load_file(File.expand_path("../../../config/settings.yml", __dir__))["plugins"]
    expect(settings["live_file_transfer_allowed_groups"]).to eq(
      settings["live_direct_calls_allowed_groups"],
    )
    expect(SiteSetting.live_file_transfer_allowed_groups_map).to be_empty
    expect(settings).not_to have_key("live_file_transfer_enabled")
  end

  it "requires both live access and sender group membership" do
    live_group = Fabricate(:group)
    sender_group = Fabricate(:group)
    SiteSetting.live_allowed_groups = live_group.id
    SiteSetting.live_file_transfer_allowed_groups = sender_group.id
    live_group.add(user)
    sender_group.add(user)
    sender_group.add(other_user)

    expect(described_class.for_users([user, other_user])).to eq(Set[user.id])
    SiteSetting.live_file_transfer_allowed_groups = ""
    expect(described_class.for_users([user, other_user])).to be_empty
    SiteSetting.live_file_transfer_allowed_groups = sender_group.id
    SiteSetting.live_enabled = false
    expect(described_class.for_users([user, other_user])).to be_empty
  end

  it "supports logged-in pseudo groups without membership rows and excludes bots" do
    SiteSetting.live_allowed_groups = Group::AUTO_GROUPS[:logged_in_users]
    SiteSetting.live_file_transfer_allowed_groups = Group::AUTO_GROUPS[:logged_in_users]
    expect(described_class.for_users([user, Discourse.system_user])).to eq(Set[user.id])
  end
end
