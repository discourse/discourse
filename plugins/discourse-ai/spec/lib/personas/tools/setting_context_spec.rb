# frozen_string_literal: true

def has_rg?
  if defined?(@has_rg)
    @has_rg
  else
    @has_rg |= system("which rg")
  end
end

RSpec.describe DiscourseAi::Personas::Tools::SettingContext, if: has_rg? do
  fab!(:llm_model)

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def setting_context(setting_name)
    described_class.new({ setting_name: setting_name }, bot_user: bot_user, llm: llm)
  end

  describe "#execute" do
    it "returns the context for core setting" do
      result = setting_context("moderators_view_emails").invoke

      expect(result[:setting_name]).to eq("moderators_view_emails")

      expect(result[:context]).to include("site_settings.yml")
      expect(result[:context]).to include("moderators_view_emails")
    end

    it "supports spaces and case insensitive setting name" do
      result = setting_context("moderaTors View Emails").invoke

      expect(result[:setting_name]).to eq("moderators_view_emails")

      expect(result[:context]).to include("site_settings.yml")
      expect(result[:context]).to include("moderators_view_emails")
    end

    it "returns the context for plugin setting" do
      result = setting_context("ai_bot_enabled").invoke

      expect(result[:setting_name]).to eq("ai_bot_enabled")
      expect(result[:context]).to include("ai_bot_enabled:")
    end

    context "when the setting does not exist" do
      it "returns an error message" do
        result = setting_context("this_setting_does_not_exist").invoke

        expect(result[:context]).to eq("This setting does not exist")
      end
    end
  end
end
