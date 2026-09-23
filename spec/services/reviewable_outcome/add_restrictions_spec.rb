# frozen_string_literal: true

RSpec.describe ReviewableOutcome::AddRestrictions do
  describe described_class::Contract, type: :model do
    it { is_expected.to allow_values(["account_restriction_suspension"]).for(:restriction_type) }

    it { is_expected.not_to allow_values(["unknown"]).for(:restriction_type) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:outcome, :reviewable_outcome)
    let(:params) do
      {
        outcome_id: outcome.id,
        reviewable_id: outcome.reviewable_id,
        user_id: outcome.reviewable.target_created_by_id,
        restriction_type: ["account_restriction_suspension"],
      }
    end
    let(:dependencies) { {} }

    context "when reporting is disabled" do
      it "preserves the existing outcome" do
        expect { result }.not_to change { outcome.reload.restriction_type }
      end
    end

    context "when reporting is enabled" do
      before { SiteSetting.reviewable_outcome_reporting_enabled = true }

      it "adds multiple restrictions and does not duplicate them on retry" do
        params[:restriction_type] = %w[
          account_restriction_suspension
          visibility_restriction_removal
        ]

        expect(result).to run_successfully
        expect(described_class.call(params:)).to run_successfully
        expect(outcome.reload.restriction_type).to eq(
          %w[account_restriction_suspension visibility_restriction_removal],
        )
      end

      it "refuses to attach a penalty to another reviewable" do
        params[:reviewable_id] = Fabricate(:reviewable_flagged_post).id

        expect(result).to fail_a_policy(:outcome_matches_penalized_user)
        expect(outcome.reload.restriction_type).to be_nil
      end

      it "refuses to attach a penalty to another user" do
        params[:user_id] = Fabricate(:user).id

        expect(result).to fail_a_policy(:outcome_matches_penalized_user)
        expect(outcome.reload.restriction_type).to be_nil
      end

      context "when the outcome is missing" do
        let(:params) do
          {
            outcome_id: 0,
            reviewable_id: outcome.reviewable_id,
            user_id: outcome.reviewable.target_created_by_id,
            restriction_type: ["account_restriction_suspension"],
          }
        end

        it { is_expected.to fail_to_find_a_model(:outcome) }
      end

      context "when the restriction is invalid" do
        let(:params) do
          {
            outcome_id: outcome.id,
            reviewable_id: outcome.reviewable_id,
            user_id: outcome.reviewable.target_created_by_id,
            restriction_type: ["unknown"],
          }
        end

        it { is_expected.to fail_a_contract }
      end
    end
  end
end
