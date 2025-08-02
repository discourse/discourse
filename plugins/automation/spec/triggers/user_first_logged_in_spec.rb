# frozen_string_literal: true

describe DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN do
  before { SiteSetting.discourse_automation_enabled = true }

  fab!(:user)
  let(:topic) { post.topic }

  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN)
  end

  context "when user logs in for first time" do
    it "triggers the automation" do
      contexts = capture_contexts { user.logged_in }

      expect(contexts[0]["kind"]).to eq(DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN)
      expect(contexts[0]["user"]).to eq(user)
    end
  end

  context "when user logs in multiple times" do
    it "doesn’t trigger the automation" do
      user.update_last_seen!(2.days.ago)
      contexts = capture_contexts { user.logged_in }

      expect(contexts).to eq([])
    end
  end
end
