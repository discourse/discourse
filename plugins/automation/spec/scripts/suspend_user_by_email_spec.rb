# frozen_string_literal: true

describe "SuspendUserByEmail" do
  let(:suspend_until) { 10.days.from_now }
  let(:reason) { "banned for spam" }

  fab!(:automation) do
    Fabricate(:automation, script: DiscourseAutomation::Scripts::SUSPEND_USER_BY_EMAIL)
  end
  fab!(:user)

  before do
    automation.upsert_field!("suspend_until", "date_time", { value: suspend_until })
    automation.upsert_field!("reason", "text", { value: reason })
  end

  describe "using fields" do
    it "suspends the user" do
      expect(user.suspended?).to be(false)

      expect { automation.trigger!("email" => user.email) }.to change { UserHistory.count }.by(1)

      user.reload

      expect(user.suspended?).to be(true)
      expect(user.suspended_till).to be_within_one_minute_of(suspend_until)

      user_history = UserHistory.last
      expect(user_history.details).to eq(reason)
      expect(user_history.acting_user_id).to eq(Discourse.system_user.id)
    end

    it "suspends and logs out anonymous shadow accounts", :aggregate_failures do
      SiteSetting.allow_anonymous_mode = true
      SiteSetting.anonymous_posting_allowed_groups = "11"
      master_user = Fabricate(:user, trust_level: TrustLevel[3])
      shadow_user = AnonymousShadowCreator.get(master_user)
      UserAuthToken.generate!(user_id: shadow_user.id)

      messages =
        MessageBus.track_publish("/logout/#{shadow_user.id}") do
          automation.trigger!("email" => master_user.email)
        end

      expect(shadow_user.reload[:suspended_till]).to be_within_one_minute_of(suspend_until)
      expect(shadow_user.user_auth_tokens).to be_empty
      expect(shadow_user.anonymous_user_master.reload.active).to eq(false)
      expect(messages.size).to eq(1)
      expect(messages[0].user_ids).to eq([shadow_user.id])
      expect(messages[0].data).to eq(shadow_user.id)
    end
  end

  describe "trigger override" do
    let(:reason) { "very bad behavior" }
    let(:suspend_until) { 20.days.from_now }

    it "suspends the user" do
      expect(user.suspended?).to be(false)

      expect {
        automation.trigger!(
          "email" => user.email,
          "reason" => reason,
          "suspend_until" => suspend_until,
        )
      }.to change { UserHistory.count }.by(1)

      user.reload

      expect(user.suspended?).to be(true)
      expect(user.suspended_till).to be_within_one_minute_of(suspend_until)
      expect(UserHistory.last.details).to eq(reason)
    end
  end
end
