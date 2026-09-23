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

      it "does not attach a penalty when the reviewable has no outcome" do
        params[:reviewable_id] = Fabricate(:reviewable_flagged_post).id

        expect(result).to run_successfully
        expect(outcome.reload.restriction_type).to be_nil
      end

      it "does not attach a penalty to another user" do
        params[:user_id] = Fabricate(:user).id

        expect(result).to run_successfully
        expect(outcome.reload.restriction_type).to be_nil
      end

      it "adds suspension for an account reviewable" do
        user = Fabricate(:user)
        reviewable = Fabricate(:reviewable_user, target: user)
        account_outcome = Fabricate(:reviewable_outcome, reviewable:)
        params[:reviewable_id] = reviewable.id
        params[:user_id] = user.id

        expect(result).to run_successfully
        expect(account_outcome.reload.restriction_type).to eq(["account_restriction_suspension"])
      end

      context "when the restriction is invalid" do
        let(:params) do
          {
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
