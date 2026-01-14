# frozen_string_literal: true

describe Plugin::Instance do
  before { enable_current_plugin }

  describe "current_user_serializer#ai_helper_prompts" do
    fab!(:user)

    before do
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_helper_enabled = true
      SiteSetting.ai_helper_illustrate_post_model = "disabled"
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
end
