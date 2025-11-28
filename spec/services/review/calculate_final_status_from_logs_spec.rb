# frozen_string_literal: true

RSpec.describe Review::CalculateFinalStatusFromLogs do
  describe ".call" do
    fab!(:moderator)
    fab!(:user)
    fab!(:reviewable_user) { ReviewableUser.create_for(user) }
    fab!(:reviewable, :reviewable_flagged_post)
    let(:guardian) { Guardian.new(moderator) }

    before do
      SiteSetting.reviewable_old_moderator_actions = false
      allow_any_instance_of(Guardian).to receive(:can_see_reviewable_ui_refresh?).and_return(true)
    end

    context "when all bundles are actioned" do
      fab!(:reviewable_deleted, :reviewable_queued_post)

      it "returns deleted when a log has deleted statuses" do
        reviewable_deleted.reviewable_action_logs.create!(
          action_key: "delete",
          status: :deleted,
          performed_by: moderator,
          bundle: "post-actions",
        )
        reviewable_deleted.reviewable_action_logs.create!(
          action_key: "no_action_user",
          status: :ignored,
          performed_by: moderator,
          bundle: "user-actions",
        )

        result =
          described_class.call(params: { reviewable_id: reviewable_deleted.id, guardian: guardian })
        expect(result).to be_a_success
        expect(result.status).to eq(:deleted)
      end

      it "returns ignored status when all logs are ignored" do
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

        result = described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
        expect(result).to be_a_success
        expect(result.status).to eq(:ignored)
      end

      it "returns rejected status when all logs are rejected" do
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

        result = described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
        expect(result).to be_a_success
        expect(result.status).to eq(:rejected)
      end

      it "returns approved status when any log is approved" do
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

        result = described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
        expect(result).to be_a_success
        expect(result.status).to eq(:approved)
      end

      it "returns rejected status when logs have mixed rejected and ignored statuses" do
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

        result = described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
        expect(result).to be_a_success
        expect(result.status).to eq(:rejected)
      end
    end

    it "uses the latest action when multiple actions exist for the same bundle" do
      reviewable.reviewable_action_logs.create!(
        action_key: "hide_post",
        status: :approved,
        performed_by: moderator,
        bundle: "post-actions",
      )
      reviewable.reviewable_action_logs.create!(
        action_key: "no_action_post",
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

      result = described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
      expect(result).to be_a_success
      expect(result.status).to eq(:ignored)
    end

    it "succeeds for reviewable with single bundle" do
      reviewable_user.reviewable_action_logs.create!(
        action_key: "approve_user",
        status: :approved,
        performed_by: moderator,
        bundle: "user-actions",
      )

      result =
        described_class.call(params: { reviewable_id: reviewable_user.id, guardian: guardian })
      expect(result).to be_a_success
      expect(result.status).to eq(:approved)
    end

    it "fails when not all bundles are actioned" do
      reviewable.reviewable_action_logs.create!(
        action_key: "edit_post",
        status: :approved,
        performed_by: moderator,
        bundle: "post-actions",
      )

      result = described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
      expect(result).to be_a_failure
    end

    it "fails when no logs exist" do
      result = described_class.call(params: { reviewable_id: reviewable.id, guardian: guardian })
      expect(result).to be_a_failure
    end
  end
end
