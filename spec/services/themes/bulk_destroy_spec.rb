# frozen_string_literal: true

RSpec.describe Themes::BulkDestroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_ids) }
    it { is_expected.to allow_values([1], (1..50).to_a).for(:theme_ids) }
    it { is_expected.not_to allow_values([], (1..51).to_a).for(:theme_ids) }
    it do
      is_expected.not_to allow_values([1, 0, -3]).for(:theme_ids).with_message(
        /must all be positive/,
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:theme_1) { Fabricate(:theme) }
    fab!(:theme_2) { Fabricate(:theme) }
    fab!(:admin)

    let(:params) { { theme_ids: [theme_1.id, theme_2.id] } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when data is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when a theme does not exist" do
      before do
        theme_1.destroy!
        theme_2.destroy!
      end

      it { is_expected.to fail_to_find_a_model(:themes) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "destroys the themes" do
        expect { result }.to change { Theme.count }.by(-2)
      end

      it "logs the theme destroys" do
        expect_any_instance_of(StaffActionLogger).to receive(:log_theme_destroy).with(theme_1).once
        expect_any_instance_of(StaffActionLogger).to receive(:log_theme_destroy).with(theme_2).once
        result
      end
    end
  end
end
