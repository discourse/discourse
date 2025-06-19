# frozen_string_literal: true

RSpec.describe Themes::BulkDestroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_ids) }

    it "validates length of theme_ids" do
      contract = described_class.new(theme_ids: [1, 2, 3])
      contract.validate
      expect(contract.errors).to be_empty

      contract = described_class.new(theme_ids: (1..55).to_a)
      contract.validate
      expect(contract.errors.full_messages).to include(
        "Theme ids " + I18n.t("errors.messages.too_long", count: 50),
      )

      contract = described_class.new(theme_ids: [])
      contract.validate
      expect(contract.errors.full_messages).to include(
        "Theme ids " + I18n.t("errors.messages.too_short", count: 1),
      )
    end

    describe "theme_ids must be positive, negative IDs are system themes" do
      context "when all theme_ids are positive" do
        it "is valid" do
          contract = described_class.new(theme_ids: [1, 2, 3])
          contract.validate
          expect(contract.errors).to be_empty
        end
      end

      context "when any theme_id is zero or negative" do
        it "is invalid " do
          contract = described_class.new(theme_ids: [1, 0, -3])
          contract.validate
          expect(contract.errors.full_messages).to include(
            "Theme ids " + I18n.t("errors.messages.must_all_be_positive"),
          )
        end
      end
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
