# frozen_string_literal: true

RSpec.describe McpServerProfile do
  fab!(:admin)
  fab!(:moderator)

  it "always allows administrators without automatically allowing moderators" do
    profile =
      described_class.create!(
        name: "Administrator access",
        slug: "administrator-access",
        allowed_group_ids: [],
        allowed_scopes: [],
      )

    expect(profile.allowed_group_ids).to eq([Group::AUTO_GROUPS[:admins]])
    expect(profile.user_allowed?(admin)).to eq(true)
    expect(profile.user_allowed?(moderator)).to eq(false)
  end
end
