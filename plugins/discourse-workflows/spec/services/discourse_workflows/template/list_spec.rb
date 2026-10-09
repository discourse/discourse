# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Template::List do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:admin)
    let(:dependencies) { { guardian: admin.guardian } }

    before { DiscourseWorkflows::TemplateStore.reset_cache! }
    after { DiscourseWorkflows::TemplateStore.reset_cache! }

    context "when user is not admin" do
      fab!(:user)
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when there are no templates" do
      before { DiscourseWorkflows::TemplateStore.stubs(:summaries).returns([]) }

      it { is_expected.to run_successfully }
    end

    context "when every node type is available" do
      it { is_expected.to run_successfully }

      it "returns available template summaries without plugins or requirements" do
        template = result[:templates].find { |t| t[:id] == "auto-tag-topics" }
        expect(template).to include(plugins: [], missing_requirements: [], available: true)
      end
    end

    context "when a template relies on plugin nodes" do
      before do
        SiteSetting.chat_enabled = false
        DiscourseWorkflows::TemplateStore.stubs(:summaries).returns(
          [
            {
              id: "needs-plugins",
              node_types: %w[
                trigger:topic_created
                action:send_chat_message
                action:chat_approval
                action:not_installed
              ],
            },
          ],
        )
      end

      it "lists each plugin once and unexplained nodes as requirements" do
        expect(result[:templates].first).to include(
          plugins: [{ name: "Chat", enabled: false }],
          missing_requirements: [{ node_type: "action:not_installed", reason_key: nil }],
          available: false,
        )
      end
    end
  end
end
