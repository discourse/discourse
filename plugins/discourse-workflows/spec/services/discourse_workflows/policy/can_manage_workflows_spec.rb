# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Policy::CanManageWorkflows do
  subject(:policy) { described_class.new(Service::Base::Context.build(guardian:)) }

  describe "#call" do
    context "when guardian belongs to an admin" do
      fab!(:admin)
      let(:guardian) { admin.guardian }

      it { expect(policy.call).to eq(true) }
    end

    context "when guardian belongs to a regular user" do
      fab!(:user)
      let(:guardian) { user.guardian }

      it { expect(policy.call).to eq(false) }
    end
  end

  describe "#reason" do
    fab!(:user)
    let(:guardian) { user.guardian }

    it "returns the no-permission i18n string" do
      expect(policy.reason).to eq(I18n.t("discourse_workflows.errors.no_permission_to_manage"))
    end
  end
end
