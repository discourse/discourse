# frozen_string_literal: true

RSpec.describe DiscourseAutomation::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :automation_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:admin) }
    fab!(:automation) { Fabricate(:automation) }

    let(:guardian) { user.guardian }
    let(:params) { { automation_id: automation.id } }
    let(:dependencies) { { guardian: } }

    context "when user can't destroy the automation" do
      fab!(:user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:can_destroy_automation) }
    end

    context "when data is invalid" do
      before { params[:automation_id] = nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the automation is not found" do
      before { params[:automation_id] = 999 }

      it { is_expected.to fail_to_find_a_model(:automation) }
    end

    context "when everything's ok" do
      it "logs the action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last.details).to eq(
          "id: #{automation.id}\nname: #{automation.name}\nscript: #{automation.script}\ntrigger: #{automation.trigger}",
        )
      end

      it "destroys the automation" do
        expect { result }.to change { DiscourseAutomation::Automation.count }.by(-1)
      end
    end
  end
end
