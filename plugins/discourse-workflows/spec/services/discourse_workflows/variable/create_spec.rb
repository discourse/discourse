# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Variable::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_presence_of(:value) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:params) { { key: "API_BASE_URL", value: "https://example.com", description: "Base URL" } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { key: nil, value: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates the variable" do
        expect { result }.to change { DiscourseWorkflows::Variable.count }.by(1)
        expect(DiscourseWorkflows::Variable.last).to have_attributes(
          key: "API_BASE_URL",
          value: "https://example.com",
          description: "Base URL",
        )
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_variable_created",
          subject: "API_BASE_URL",
        )
      end
    end
  end
end
