# frozen_string_literal: true

RSpec.describe Reviewable::RecordOutcome do
  describe described_class::Contract, type: :model do
    it { is_expected.to allow_values("human", "automated").for(:outcome_source) }
    it { is_expected.not_to allow_values("unknown").for(:outcome_source) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:reviewable, :reviewable_flagged_post)
    let(:params) { { outcome_source: "human", restriction_type: nil } }
    let(:dependencies) { { reviewable: } }

    context "when reporting is disabled" do
      it "does not write an outcome" do
        expect { result }.not_to change { ReviewableOutcome.count }
      end
    end

    context "when reporting is enabled" do
      before { SiteSetting.reviewable_outcome_reporting_enabled = true }

      it "records the handling with no restriction" do
        expect(result).to run_successfully
        expect(reviewable.reload.reviewable_outcome).to have_attributes(
          outcome_source: "human",
          legal_basis: "tos_violation",
          restriction_type: nil,
        )
      end

      it "records the illegal-content basis and every supplied restriction" do
        reviewable.update!(potentially_illegal: true)
        params[:outcome_source] = "automated"
        params[:restriction_type] = %w[
          visibility_restriction_disable
          account_restriction_suspension
        ]

        expect(result).to run_successfully
        expect(reviewable.reload.reviewable_outcome).to have_attributes(
          outcome_source: "automated",
          legal_basis: "illegal content",
          restriction_type: %w[visibility_restriction_disable account_restriction_suspension],
        )
      end

      it "replaces an earlier outcome when the later decision applies no restriction" do
        outcome =
          Fabricate(
            :reviewable_outcome,
            reviewable:,
            outcome_source: "automated",
            restriction_type: ["visibility_restriction_disable"],
          )

        expect { result }.not_to change { ReviewableOutcome.count }
        expect(outcome.reload).to have_attributes(
          outcome_source: "human",
          legal_basis: "tos_violation",
          restriction_type: nil,
        )
      end

      context "when the source is invalid" do
        let(:params) { { outcome_source: "unknown", restriction_type: nil } }

        it { is_expected.to fail_a_contract }
      end
    end
  end
end
