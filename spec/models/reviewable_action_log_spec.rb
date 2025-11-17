# frozen_string_literal: true

RSpec.describe ReviewableActionLog, type: :model do
  fab!(:moderator)
  fab!(:reviewable, :reviewable_flagged_post)

  describe ".calculate_final_status" do
    it "returns ignored when all logs are ignored" do
      log1 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "ignore_and_do_nothing",
          status: :ignored,
          performed_by: moderator,
        )
      log2 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "ignore_user",
          status: :ignored,
          performed_by: moderator,
        )

      logs = ReviewableActionLog.where(id: [log1.id, log2.id])
      expect(ReviewableActionLog.calculate_final_status(logs)).to eq(:ignored)
    end

    it "returns rejected when all logs are rejected" do
      log1 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "reject_post",
          status: :rejected,
          performed_by: moderator,
        )
      log2 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "reject_user",
          status: :rejected,
          performed_by: moderator,
        )

      logs = ReviewableActionLog.where(id: [log1.id, log2.id])
      expect(ReviewableActionLog.calculate_final_status(logs)).to eq(:rejected)
    end

    it "returns approved when any log is approved" do
      log1 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "agree_and_keep",
          status: :approved,
          performed_by: moderator,
        )
      log2 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "suspend_user",
          status: :rejected,
          performed_by: moderator,
        )

      logs = ReviewableActionLog.where(id: [log1.id, log2.id])
      expect(ReviewableActionLog.calculate_final_status(logs)).to eq(:approved)
    end

    it "returns approved when logs have mixed statuses including approved" do
      log1 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "agree_and_keep",
          status: :approved,
          performed_by: moderator,
        )
      log2 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "ignore_user",
          status: :ignored,
          performed_by: moderator,
        )

      logs = ReviewableActionLog.where(id: [log1.id, log2.id])
      expect(ReviewableActionLog.calculate_final_status(logs)).to eq(:approved)
    end

    it "returns pending for mixed rejected and ignored statuses" do
      log1 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "reject_post",
          status: :rejected,
          performed_by: moderator,
        )
      log2 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "ignore_user",
          status: :ignored,
          performed_by: moderator,
        )

      logs = ReviewableActionLog.where(id: [log1.id, log2.id])
      expect(ReviewableActionLog.calculate_final_status(logs)).to eq(:pending)
    end

    it "handles single log" do
      log =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "agree_and_keep",
          status: :approved,
          performed_by: moderator,
        )

      logs = ReviewableActionLog.where(id: log.id)
      expect(ReviewableActionLog.calculate_final_status(logs)).to eq(:approved)
    end
  end

  describe "reviewable_action_logs association on reviewable" do
    it "creates action logs associated with reviewable" do
      log =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "agree_and_keep",
          status: :approved,
          performed_by: moderator,
        )

      expect(reviewable.reviewable_action_logs).to include(log)
      expect(reviewable.reviewable_action_logs.count).to eq(1)
    end

    it "orders action logs by created_at ascending" do
      log1 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "agree_and_keep",
          status: :approved,
          performed_by: moderator,
        )
      log2 =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "suspend_user",
          status: :rejected,
          performed_by: moderator,
        )

      expect(reviewable.reviewable_action_logs.to_a).to eq([log1, log2])
    end

    it "deletes action logs when reviewable is destroyed" do
      log =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "agree_and_keep",
          status: :approved,
          performed_by: moderator,
        )

      reviewable.destroy!
      expect(ReviewableActionLog.exists?(log.id)).to be false
    end
  end
end
