# frozen_string_literal: true

RSpec.describe FlaggedUserSerializer do
  fab!(:admin)
  fab!(:moderator)
  fab!(:flagged_user) { Fabricate(:user, email: "flagged@example.com", refresh_auto_groups: true) }

  it "includes email for admins and moderators with permission" do
    serializer = FlaggedUserSerializer.new(flagged_user, scope: Guardian.new(admin), root: false)
    json = serializer.as_json
    expect(json[:email]).to eq("flagged@example.com")

    serializer =
      FlaggedUserSerializer.new(flagged_user, scope: Guardian.new(moderator), root: false)
    json = serializer.as_json
    expect(json[:email]).to be_nil

    SiteSetting.moderators_view_emails = true
    serializer =
      FlaggedUserSerializer.new(flagged_user, scope: Guardian.new(moderator), root: false)
    json = serializer.as_json
    expect(json[:email]).to eq("flagged@example.com")
  end
end
