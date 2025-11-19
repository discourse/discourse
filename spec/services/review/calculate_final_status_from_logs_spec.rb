# frozen_string_literal: true

RSpec.describe Review::CalculateFinalStatusFromLogs do
  describe ".call" do
    fab!(:moderator)
    fab!(:user)
    fab!(:reviewable, :reviewable_flagged_post)
    let(:guardian) { Guardian.new(moderator) }

    before do
      SiteSetting.reviewable_old_moderator_actions = false
      allow_any_instance_of(Guardian).to receive(:can_see_reviewable_ui_refresh?).and_return(true)
    end

    context "when all bundles are actioned" do
      context "when all logs are ignored" do
        before do
          reviewable.reviewable_action_logs.create!(
            action_key: "ignore_and_do_nothing",
            status: :ignored,
            performed_by: moderator,
            bundle: "post-actions",
          )
          reviewable.reviewable_action_logs.create!(
            action_key: "no_action_user",
            status: :ignored,
            performed_by: moderator,
            bundle: "user-actions",
          )
        end

        it "returns ignored status" do
          result =
            described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
          expect(result).to be_a_success
          expect(result.status).to eq(:ignored)
        end
      end

      context "when all logs are rejected" do
        before do
          reviewable.reviewable_action_logs.create!(
            action_key: "hide_post",
            status: :rejected,
            performed_by: moderator,
            bundle: "post-actions",
          )
          reviewable.reviewable_action_logs.create!(
            action_key: "suspend_user",
            status: :rejected,
            performed_by: moderator,
            bundle: "user-actions",
          )
        end

        it "returns rejected status" do
          result =
            described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
          expect(result).to be_a_success
          expect(result.status).to eq(:rejected)
        end
      end

      context "when any log is approved" do
        before do
          reviewable.reviewable_action_logs.create!(
            action_key: "agree_and_keep",
            status: :approved,
            performed_by: moderator,
            bundle: "post-actions",
          )
          reviewable.reviewable_action_logs.create!(
            action_key: "suspend_user",
            status: :rejected,
            performed_by: moderator,
            bundle: "user-actions",
          )
        end

        it "returns approved status" do
          result =
            described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
          expect(result).to be_a_success
          expect(result.status).to eq(:approved)
        end
      end

      context "when logs have mixed rejected and ignored statuses" do
        before do
          reviewable.reviewable_action_logs.create!(
            action_key: "hide_post",
            status: :rejected,
            performed_by: moderator,
            bundle: "post-actions",
          )
          reviewable.reviewable_action_logs.create!(
            action_key: "no_action_user",
            status: :ignored,
            performed_by: moderator,
            bundle: "user-actions",
          )
        end

        it "returns rejected status (rejected takes priority over ignored)" do
          result =
            described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
          expect(result).to be_a_success
          expect(result.status).to eq(:rejected)
        end
      end
    end

    context "when not all bundles are actioned" do
      before do
        reviewable.reviewable_action_logs.create!(
          action_key: "edit_post",
          status: :approved,
          performed_by: moderator,
          bundle: "post-actions",
        )
      end

      it "fails" do
        result = described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
        expect(result).to be_a_failure
      end
    end

    context "when no logs exist" do
      it "fails" do
        result = described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
        expect(result).to be_a_failure
      end
    end

    context "for reviewable with single bundle" do
      let(:reviewable_user) { ReviewableUser.create_for(user) }

      before do
        reviewable_user.reviewable_action_logs.create!(
          action_key: "approve_user",
          status: :approved,
          performed_by: moderator,
          bundle: "user-actions",
        )
      end

      it "succeeds when that bundle is actioned" do
        result =
          described_class.call(params: { reviewable_id: reviewable_user.id, guardian: guardian })
        expect(result).to be_a_success
        expect(result.status).to eq(:approved)
      end
    end
  end
end
