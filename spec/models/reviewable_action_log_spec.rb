# frozen_string_literal: true

RSpec.describe ReviewableActionLog, type: :model do
  fab!(:moderator)
  fab!(:reviewable, :reviewable_flagged_post)

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
