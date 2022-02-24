# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'UserPromoted' do
  before do
    SiteSetting.discourse_automation_enabled = true
  end

  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:automation) { Fabricate(:automation, trigger: DiscourseAutomation::Triggerable::USER_PROMOTED) }

  it "runs without any restrictions" do
    output = capture_stdout do
      user.change_trust_level!(TrustLevel[1])
    end
    expect(output).to include('"kind":"user_promoted"')
    expect(output).to include('"placeholders":{"trust_level_transition":"from new user to basic user"}}')
  end

  it "does not run if the user is being demoted" do
    capture_stdout { user.change_trust_level!(TrustLevel[4]) }

    output = capture_stdout do
      user.change_trust_level!(TrustLevel[1])
    end
    expect(output).not_to include('"kind":"user_promoted"')
  end

  context "when there is a group restriction" do
    let!(:group) { Fabricate(:group) }
    before do
      automation.upsert_field!("restricted_group", "group", { "value" => group.id }, target: "trigger")
    end

    it "does not run if the user is not part of the group" do
      output = capture_stdout do
        user.change_trust_level!(TrustLevel[1])
      end
      expect(output).not_to include('"kind":"user_promoted"')
    end

    it "does run if the user is part of the group" do
      Fabricate(:group_user, group: group, user: user)
      output = capture_stdout do
        user.change_trust_level!(TrustLevel[1])
      end
      expect(output).to include('"kind":"user_promoted"')
    end
  end

  context "when there is a trust_level_transition restriction" do
    before do
      automation.upsert_field!("trust_level_transition", "choices", { "value" => "TL01" }, target: "trigger")
    end

    it "does not run if the trust level transition does not match" do
      user.change_trust_level!(TrustLevel[2])
      output = capture_stdout do
        user.change_trust_level!(TrustLevel[3])
      end
      expect(output).not_to include('"kind":"user_promoted"')
    end

    it "does run if the trust level transition matches" do
      capture_stdout { user.change_trust_level!(TrustLevel[0]) }

      output = capture_stdout do
        user.change_trust_level!(TrustLevel[1])
      end
      expect(output).to include('"kind":"user_promoted"')
    end

    it "does run if the transition is for all trust levels" do
      automation.upsert_field!("trust_level_transition", "choices", { "value" => "TLALL" }, target: "trigger")
      capture_stdout { user.change_trust_level!(TrustLevel[2]) }

      output = capture_stdout do
        user.change_trust_level!(TrustLevel[4])
      end
      expect(output).to include('"kind":"user_promoted"')
    end
  end
end
