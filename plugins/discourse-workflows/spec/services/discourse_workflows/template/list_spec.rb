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

    context "when templates exist" do
      it { is_expected.to run_successfully }

      it "returns templates with the expected attributes" do
        template = result[:templates].first
        expect(template).to include(:id, :name, :description, :node_types)
      end

      it "includes known templates from config/templates" do
        ids = result[:templates].map { |t| t[:id] }
        expect(ids).to include("auto-tag-topics")
      end
    end

    context "when a template file has invalid JSON" do
      before do
        FileUtils.mkdir_p(DiscourseWorkflows::TEMPLATES_PATH)
        File.write(
          File.join(DiscourseWorkflows::TEMPLATES_PATH, "broken.json"),
          "not valid json{{{",
        )
      end

      after { FileUtils.rm_f(File.join(DiscourseWorkflows::TEMPLATES_PATH, "broken.json")) }

      it { is_expected.to run_successfully }

      it "skips the malformed template" do
        ids = result[:templates].map { |t| t[:id] }
        expect(ids).not_to include("broken")
      end
    end

    context "when no template files exist" do
      before { DiscourseWorkflows::TemplateStore.stubs(:summaries).returns([]) }

      it { is_expected.to run_successfully }

      it "returns an empty array" do
        expect(result[:templates]).to eq([])
      end
    end
  end
end
