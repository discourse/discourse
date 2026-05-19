# frozen_string_literal: true

RSpec.describe User do
  describe "anonymous shadow account state" do
    fab!(:admin)
    fab!(:master_user) { Fabricate(:user, trust_level: TrustLevel[3]) }

    before do
      SiteSetting.allow_anonymous_mode = true
      SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
    end

    it "uses the shadow account's own state" do
      shadow_user = AnonymousShadowCreator.get(master_user)

      master_user.update!(
        active: false,
        suspended_at: Time.zone.now,
        suspended_till: 1.day.from_now,
      )

      shadow_user.reload

      expect(shadow_user.active).to eq(true)
      expect(shadow_user).to be_active
      expect(shadow_user.suspended_till).to be_nil
      expect(shadow_user).not_to be_suspended
    end

    it "deactivates and logs out shadows with the master" do
      shadow_user = AnonymousShadowCreator.get(master_user)
      UserAuthToken.generate!(user_id: shadow_user.id)

      messages =
        MessageBus.track_publish("/logout/#{shadow_user.id}") { master_user.deactivate(admin) }

      expect(shadow_user.reload[:active]).to eq(false)
      expect(shadow_user.user_auth_tokens).to be_empty
      expect(shadow_user.anonymous_user_master.reload.active).to eq(false)
      expect(messages.size).to eq(1)
      expect(messages[0].user_ids).to eq([shadow_user.id])
      expect(messages[0].data).to eq(shadow_user.id)
    end
  end
end
