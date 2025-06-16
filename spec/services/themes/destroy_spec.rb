# frozen_string_literal: true

RSpec.describe Themes::Destroy do
  fab!(:theme)
  fab!(:admin)

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:id) }
    it { is_expected.to validate_numericality_of(:id).only_integer.is_greater_than(0) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    let(:params) { { id: theme.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    it { is_expected.to run_successfully }

    it "destroys the theme" do
      expect { result }.to change { Theme.find_by(id: theme.id) }.to(nil)
    end

    it "logs the theme destroy" do
      expect_any_instance_of(StaffActionLogger).to receive(:log_theme_destroy).with(theme)

      expect(result).to be_a_success
    end

    context "for invalid theme id" do
      before { theme.destroy! }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end
  end
end
