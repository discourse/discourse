# frozen_string_literal: true

RSpec.describe Experiments::Toggle do
  subject(:result) { described_class.call(params) }

  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new }

    it { is_expected.to validate_presence_of :setting_name }
  end

  fab!(:admin)
  let(:params) { { setting_name:, guardian: } }
  let(:setting_name) { :experimental_form_templates }
  let(:guardian) { admin.guardian }

  context "when setting_name is blank" do
    let(:setting_name) { nil }

    it { is_expected.to fail_a_contract }
  end

  context "when setting_name is invalid" do
    let(:setting_name) { "wrong_value" }

    it { is_expected.to fail_a_policy(:setting_is_available) }
  end

  context "when a non-admin user tries to change a setting" do
    let(:guardian) { Guardian.new }

    it { is_expected.to fail_a_policy(:current_user_is_admin) }
  end

  context "when the admin toggles the feature" do
    it { is_expected.to run_successfully }

    it "enables the specified setting" do
      expect { result }.to change { SiteSetting.experimental_form_templates }.to(true)
    end

    it "disables the specified setting" do
      SiteSetting.experimental_form_templates = true
      expect { result }.to change { SiteSetting.experimental_form_templates }.to(false)
    end

    it "creates an entry in the staff action logs" do
      expect { result }.to change {
        UserHistory.where(
          action: UserHistory.actions[:change_site_setting],
          subject: "experimental_form_templates",
        ).count
      }.by(1)
    end
  end
end
