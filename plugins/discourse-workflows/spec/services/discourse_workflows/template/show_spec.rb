# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Template::Show do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:template_id) }
    it do
      is_expected.to allow_values("auto-tag-topics", "my_template", "test123").for(:template_id)
    end
    it do
      is_expected.not_to allow_values("../etc/passwd", "UPPER", "with spaces", "with/slash").for(
        :template_id,
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:params) { { template_id: } }
    let(:template_id) { "auto-tag-topics" }
    let(:dependencies) { { guardian: admin.guardian } }

    before { DiscourseWorkflows::TemplateStore.reset_cache! }
    after { DiscourseWorkflows::TemplateStore.reset_cache! }

    context "when contract is invalid" do
      let(:template_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when template is not found" do
      let(:template_id) { "nonexistent-template" }

      it { is_expected.to fail_to_find_a_model(:template) }
    end

    context "when template exists" do
      it { is_expected.to run_successfully }

      it "returns the parsed template data" do
        expect(result[:template]).to be_a(Hash)
        expect(result[:template]["name"]).to eq("Auto-tag new topics")
      end
    end
  end
end
