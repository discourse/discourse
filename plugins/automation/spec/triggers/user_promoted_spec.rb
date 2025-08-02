# frozen_string_literal: true

describe "UserPromoted" do
  before { SiteSetting.discourse_automation_enabled = true }

  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::USER_PROMOTED)
  end

  it "runs without any restrictions" do
    list = capture_contexts { user.change_trust_level!(TrustLevel[1]) }

    expect(list.length).to eq(1)
    expect(list[0]["kind"]).to eq("user_promoted")
    expect(list[0]["placeholders"]).to eq(
      { "trust_level_transition" => "from new user to basic user" },
    )
  end

  it "does not run if the user is being demoted" do
    user.change_trust_level!(TrustLevel[4])

    list = capture_contexts { user.change_trust_level!(TrustLevel[1]) }

    expect(list).to eq([])
  end

  context "when there is a group restriction" do
    let!(:group) { Fabricate(:group) }
    before do
      automation.upsert_field!(
        "restricted_group",
        "group",
        { "value" => group.id },
        target: "trigger",
      )
    end

    it "does not run if the user is not part of the group" do
      list = capture_contexts { user.change_trust_level!(TrustLevel[1]) }

      expect(list).to eq([])
    end

    it "does run if the user is part of the group" do
      Fabricate(:group_user, group: group, user: user)
      list = capture_contexts { user.change_trust_level!(TrustLevel[1]) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("user_promoted")
    end
  end

  context "when there is a trust_level_transition restriction" do
    before do
      automation.upsert_field!(
        "trust_level_transition",
        "choices",
        { "value" => "TL01" },
        target: "trigger",
      )
    end

    it "does not run if the trust level transition does not match" do
      user.change_trust_level!(TrustLevel[2])

      list = capture_contexts { user.change_trust_level!(TrustLevel[3]) }

      expect(list).to eq([])
    end

    it "does run if the trust level transition matches" do
      user.change_trust_level!(TrustLevel[0])

      list = capture_contexts { user.change_trust_level!(TrustLevel[1]) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to include("user_promoted")
    end

    it "does run if the transition is for all trust levels" do
      automation.upsert_field!(
        "trust_level_transition",
        "choices",
        { "value" => "TLALL" },
        target: "trigger",
      )

      user.change_trust_level!(TrustLevel[2])

      list = capture_contexts { user.change_trust_level!(TrustLevel[4]) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("user_promoted")
    end
  end
end
