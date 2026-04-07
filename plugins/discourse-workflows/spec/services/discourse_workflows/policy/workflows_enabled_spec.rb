# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Policy::WorkflowsEnabled do
  subject(:policy) { described_class.new(context) }

  let(:context) { Service::Base::Context.build }

  describe "#call" do
    context "when discourse_workflows_enabled is true" do
      before { SiteSetting.discourse_workflows_enabled = true }

      it { expect(policy.call).to be true }
    end

    context "when discourse_workflows_enabled is false" do
      before { SiteSetting.discourse_workflows_enabled = false }

      it { expect(policy.call).to be false }
    end
  end

  describe "#reason" do
    it { expect(policy.reason).to eq(I18n.t("discourse_workflows.errors.not_enabled")) }
  end
end
