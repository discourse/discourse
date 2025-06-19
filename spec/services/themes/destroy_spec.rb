# frozen_string_literal: true

RSpec.describe Themes::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:id) }
    it { is_expected.to allow_values(1, "1", 42).for(:id) }
    it { is_expected.not_to allow_values(-1, 0).for(:id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:theme)
    fab!(:admin)

    let(:params) { { id: theme.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when data is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "for invalid theme id" do
      before { theme.destroy! }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "destroys the theme" do
        expect { result }.to change { Theme.find_by(id: theme.id) }.to(nil)
      end

      it "logs the theme destroy" do
        expect_any_instance_of(StaffActionLogger).to receive(:log_theme_destroy).with(theme)
        result
      end
    end
  end
end
