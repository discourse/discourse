# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::SettingContext,
               if: system("which rg", out: File::NULL) do
  fab!(:llm_model)

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  describe "#execute" do
    it "returns the context for core setting" do
      result =
        described_class.new(
          { setting_name: "moderators_view_emails" },
          bot_user: bot_user,
          llm: llm,
        ).invoke

      expect(result[:setting_name]).to eq("moderators_view_emails")

      expect(result[:context]).to include("site_settings.yml")
      expect(result[:context]).to include("moderators_view_emails")
    end

    it "supports spaces and case insensitive setting name" do
      result =
        described_class.new(
          { setting_name: "moderaTors View Emails" },
          bot_user: bot_user,
          llm: llm,
        ).invoke

      expect(result[:setting_name]).to eq("moderators_view_emails")

      expect(result[:context]).to include("site_settings.yml")
      expect(result[:context]).to include("moderators_view_emails")
    end

    it "returns the context for plugin setting" do
      result =
        described_class.new({ setting_name: "ai_bot_enabled" }, bot_user: bot_user, llm: llm).invoke

      expect(result[:setting_name]).to eq("ai_bot_enabled")
      expect(result[:context]).to include("ai_bot_enabled:")
    end

    context "when the setting does not exist" do
      it "returns an error message" do
        result =
          described_class.new(
            { setting_name: "this_setting_does_not_exist" },
            bot_user: bot_user,
            llm: llm,
          ).invoke

        expect(result[:context]).to eq("This setting does not exist")
      end
    end
  end
end
