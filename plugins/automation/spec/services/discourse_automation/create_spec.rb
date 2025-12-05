# frozen_string_literal: true

RSpec.describe DiscourseAutomation::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :script }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:guardian) { admin.guardian }
    let(:params) { { script: "post", trigger: "topic" } }
    let(:dependencies) { { guardian: } }

    context "when user can't create an automation" do
      fab!(:user)
      let(:guardian) { user.guardian }

      it { is_expected.to fail_a_policy(:can_create_automation) }
    end

    context "when data is invalid" do
      before { params[:script] = nil }

      it { is_expected.to fail_a_contract }
    end

    context "when everything's ok" do
      it "creates the automation" do
        expect { result }.to change { DiscourseAutomation::Automation.count }.by(1)
      end

      it "logs the action" do
        expect { result }.to change {
          UserHistory.where(custom_type: "create_automation").count
        }.by(1)

        user_history = UserHistory.last
        expect(user_history.details).to include("script: post")
        expect(user_history.details).to include("trigger: topic")
      end

      it "does not log empty values" do
        params[:trigger] = nil
        result

        user_history = UserHistory.last
        expect(user_history.details).not_to include("trigger:")
      end
    end

    context "with forced triggerable" do
      let(:script_name) { "test_forced_triggerable" }

      before do
        DiscourseAutomation::Scriptable.add(script_name) do
          triggerable! :recurring, { recurrence: { interval: 1, frequency: "day" } }
        end
        params[:script] = script_name
        params[:trigger] = nil
      end

      after { DiscourseAutomation::Scriptable.remove(script_name) }

      it "applies the forced triggerable" do
        result
        expect(result[:automation].trigger).to eq("recurring")
      end
    end
  end
end
