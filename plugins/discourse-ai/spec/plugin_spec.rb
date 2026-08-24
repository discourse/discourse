# frozen_string_literal: true

describe Plugin::Instance do
  before { enable_current_plugin }

  describe "current_user_serializer#ai_helper_prompts" do
    fab!(:user)

    before do
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_helper_enabled = true
      Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
      Group.refresh_automatic_groups!

      DiscourseAi::AiHelper::Assistant.clear_prompt_cache!
    end

    let(:serializer) { CurrentUserSerializer.new(user, scope: Guardian.new(user)) }

    it "returns the available prompts" do
      expect(serializer.ai_helper_prompts).to be_present

      expect(serializer.ai_helper_prompts.object.map { |p| p[:name] }).to contain_exactly(
        "translate",
        "generate_titles",
        "proofread",
        "markdown_table",
        "explain",
        "replace_dates",
      )
    end
  end

  describe "current_user_serializer#ai_triage_automations" do
    fab!(:moderator)

    it "exposes classic and agent triage automations to reviewers" do
      classic = Fabricate(:automation, name: "Classic triage", script: "llm_triage")
      agent = Fabricate(:automation, name: "Agent triage", script: "llm_agent_triage")
      Fabricate(:automation, name: "Report", script: "llm_report")

      json = CurrentUserSerializer.new(moderator, scope: moderator.guardian, root: nil).as_json

      expect(json[:ai_triage_automations]).to eq(
        [{ id: agent.id, name: agent.name }, { id: classic.id, name: classic.name }],
      )
    end

    it "does not expose triage automations to users without review access" do
      user = Fabricate(:user)

      json = CurrentUserSerializer.new(user, scope: user.guardian, root: nil).as_json

      expect(json).not_to have_key(:ai_triage_automations)
    end
  end
end
