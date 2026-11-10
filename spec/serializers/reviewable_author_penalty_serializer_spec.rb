# frozen_string_literal: true

RSpec.describe ReviewableAuthorPenaltySerializer do
  fab!(:moderator)
  fab!(:user)
  fab!(:author, :user)

  before do
    UserSilencer.silence(author, moderator, reason: "Silenced for posting links")
    UserSuspender.new(
      author,
      suspended_till: 5.days.from_now,
      reason: "Suspended for harassment",
      by_user: moderator,
    ).suspend
  end

  def reasons_for(viewer)
    Reviewable::AuthorPenalty
      .all_for(author)
      .to_h do |penalty|
        json = described_class.new(penalty, scope: Guardian.new(viewer), root: false).as_json
        [json[:kind], json[:reason]]
      end
  end

  describe "#reason" do
    it "is included for regular users when penalty reasons are not hidden" do
      expect(reasons_for(user)).to eq(
        "silence" => author.silence_reason,
        "suspension" => author.suspend_reason,
      )
    end

    it "is hidden from regular users by the setting matching the penalty kind" do
      SiteSetting.hide_suspension_reasons = true
      expect(reasons_for(user)).to eq("silence" => author.silence_reason, "suspension" => nil)

      SiteSetting.hide_suspension_reasons = false
      SiteSetting.hide_silencing_reasons = true
      expect(reasons_for(user)).to eq("silence" => nil, "suspension" => author.suspend_reason)
    end

    it "is included for staff and the penalised user when penalty reasons are hidden" do
      SiteSetting.hide_silencing_reasons = true
      SiteSetting.hide_suspension_reasons = true
      reasons = { "silence" => author.silence_reason, "suspension" => author.suspend_reason }

      expect(reasons_for(moderator)).to eq(reasons)
      expect(reasons_for(author)).to eq(reasons)
    end
  end
end
