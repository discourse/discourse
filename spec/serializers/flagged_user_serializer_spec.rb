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

  describe "#ip_address" do
    fab!(:user)

    before { flagged_user.update!(ip_address: "1.2.3.4") }

    it "includes ip_address for admins" do
      json =
        FlaggedUserSerializer.new(flagged_user, scope: Guardian.new(admin), root: false).as_json
      expect(json[:ip_address]).to eq("1.2.3.4")
    end

    it "includes ip_address for moderators when moderators_view_ips is enabled" do
      SiteSetting.moderators_view_ips = true
      json =
        FlaggedUserSerializer.new(flagged_user, scope: Guardian.new(moderator), root: false).as_json
      expect(json[:ip_address]).to eq("1.2.3.4")
    end

    it "does not include ip_address for moderators when moderators_view_ips is disabled" do
      SiteSetting.moderators_view_ips = false
      json =
        FlaggedUserSerializer.new(flagged_user, scope: Guardian.new(moderator), root: false).as_json
      expect(json[:ip_address]).to be_nil
    end

    it "does not include ip_address for regular users" do
      json = FlaggedUserSerializer.new(flagged_user, scope: Guardian.new(user), root: false).as_json
      expect(json[:ip_address]).to be_nil
    end
  end

  describe "penalty reasons" do
    fab!(:user)

    before do
      UserSilencer.silence(flagged_user, moderator, reason: "Silenced for posting links")
      UserSuspender.new(
        flagged_user,
        suspended_till: 5.days.from_now,
        reason: "Suspended for harassment",
        by_user: moderator,
      ).suspend
    end

    def serialize_for(viewer)
      FlaggedUserSerializer.new(flagged_user, scope: Guardian.new(viewer), root: false).as_json
    end

    it "includes reasons for regular users when they are not hidden" do
      expect(serialize_for(user)).to include(
        silence_reason: flagged_user.silence_reason,
        suspend_reason: flagged_user.suspend_reason,
      )
    end

    it "includes hidden reasons only for staff and the penalised user" do
      SiteSetting.hide_silencing_reasons = true
      SiteSetting.hide_suspension_reasons = true
      reasons = {
        silence_reason: flagged_user.silence_reason,
        suspend_reason: flagged_user.suspend_reason,
      }

      expect(serialize_for(user)).not_to include(:silence_reason, :suspend_reason)
      expect(serialize_for(moderator)).to include(reasons)
      expect(serialize_for(flagged_user)).to include(reasons)
    end

    it "hides the suspension reason without hiding the silence reason" do
      SiteSetting.hide_suspension_reasons = true

      json = serialize_for(user)

      expect(json).to include(silence_reason: flagged_user.silence_reason)
      expect(json).not_to include(:suspend_reason)
    end
  end
end
