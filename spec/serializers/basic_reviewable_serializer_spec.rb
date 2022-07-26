# frozen_string_literal: true

describe BasicReviewableSerializer do
  fab!(:reviewable) { Fabricate(:reviewable) }

  subject { described_class.new(reviewable, root: false).as_json }

  context "#id" do
    it "equals the reviewable's id" do
      expect(subject[:id]).to eq(reviewable.id)
    end
  end

  context "#type" do
    it "is the reviewable's type" do
      reviewable.update!(type: "ReviewableFlaggedPost")
      expect(subject[:type]).to eq("ReviewableFlaggedPost")
    end
  end

  context "#pending" do
    it "is false if the reviewable is approved" do
      reviewable.update!(status: Reviewable.statuses[:approved])
      expect(subject[:pending]).to eq(false)
    end

    it "is false if the reviewable is rejected" do
      reviewable.update!(status: Reviewable.statuses[:rejected])
      expect(subject[:pending]).to eq(false)
    end

    it "is true if the reviewable is pending" do
      reviewable.update!(status: Reviewable.statuses[:pending])
      expect(subject[:pending]).to eq(true)
    end
  end

  context "#flagger_username" do
    it "equals to the username of the user who created the reviewable" do
      reviewable.update!(
        created_by: Fabricate(:user, username: "gg.osama")
      )
      expect(subject[:flagger_username]).to eq("gg.osama")
    end
  end
end
