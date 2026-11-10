# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ListUpcomingChanges do
  fab!(:admin)
  fab!(:user)

  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) do
    described_class.new({}, bot_user: Discourse.system_user, llm: nil, context: context)
  end

  before do
    enable_current_plugin
    mock_upcoming_change_metadata(
      enable_upload_debug_mode: {
        status: :beta,
        impact: "other,developers",
      },
    )
    SiteSetting.enable_upload_debug_mode = false
  end

  describe "#invoke" do
    it "lists hidden upcoming changes without exposing unrelated settings" do
      expect(SiteSetting.hidden_settings).to include(:enable_upload_debug_mode)

      result = tool.invoke
      change = result[:changes].find { |item| item[:setting] == :enable_upload_debug_mode }

      expect(result[:url]).to eq("#{Discourse.base_url}/admin/config/upcoming-changes")
      expect(change).to include(value: false, depends_on_met: true)
      expect(change[:upcoming_change]).to include(status: :beta, enabled_for: "no_one")
      expect(result[:changes]).to all(
        satisfy { |item| SiteSetting.upcoming_change_site_settings.include?(item[:setting]) },
      )
    end

    it "reports enabled audiences rather than treating true as enabled for everyone" do
      SiteSetting.enable_upload_debug_mode = true
      Fabricate(
        :site_setting_group,
        name: "enable_upload_debug_mode",
        group_ids: Group::AUTO_GROUPS[:staff].to_s,
      )

      change = tool.invoke[:changes].find { |item| item[:setting] == :enable_upload_debug_mode }

      expect(change[:value]).to eq(true)
      expect(change[:upcoming_change][:enabled_for]).to eq("staff")
    end

    it "distinguishes a site-wide rollout from a staff-only feature audience" do
      mock_upcoming_change_metadata(
        enable_upload_debug_mode: {
          status: :beta,
          impact_type: "feature",
          impact_role: "staff",
        },
      )
      SiteSetting.enable_upload_debug_mode = true

      change = tool.invoke[:changes].find { |item| item[:setting] == :enable_upload_debug_mode }

      expect(change[:upcoming_change]).to include(enabled_for: "everyone", impact_role: "staff")
    end

    it "preserves the admin's last visit to Upcoming Changes" do
      expect { tool.invoke }.not_to change {
        admin.reload.custom_fields["last_visited_upcoming_changes_at"]
      }
    end

    it "excludes conceptual changes" do
      mock_upcoming_change_metadata(enable_upload_debug_mode: { status: :conceptual })

      expect(tool.invoke[:changes].map { |change| change[:setting] }).not_to include(
        :enable_upload_debug_mode,
      )
    end

    it "respects conditional visibility" do
      UpcomingChanges::ConditionalDisplay.stubs(:should_display?).returns(true)
      UpcomingChanges::ConditionalDisplay
        .stubs(:should_display?)
        .with(:enable_upload_debug_mode)
        .returns(false)

      expect(tool.invoke[:changes].map { |change| change[:setting] }).not_to include(
        :enable_upload_debug_mode,
      )
    end

    it "rejects non-admin users" do
      context.user = user

      expect(tool.invoke[:status]).to eq("error")
    end

    it "rejects anonymous users" do
      context.user = nil

      expect(tool.invoke[:status]).to eq("error")
    end
  end
end
