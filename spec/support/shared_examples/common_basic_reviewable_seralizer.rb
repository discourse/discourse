# frozen_string_literal: true

RSpec.shared_examples "basic reviewable attributes" do
  describe "#id" do
    it "equals the reviewable's id" do
      expect(subject[:id]).to eq(reviewable.id)
    end
  end

  describe "#type" do
    it "is the reviewable's type" do
      expect(subject[:type]).to eq(reviewable.type)
    end
  end

  describe "#pending" do
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

  describe "#flagger_username" do
    it "equals to the username of the user who created the reviewable" do
      reviewable.update!(created_by: Fabricate(:user, username: "gg.osama"))
      expect(subject[:flagger_username]).to eq("gg.osama")
    end
  end

  describe "#created_at" do
    it "serializes the reviewable's created_at field correctly" do
      time = 10.minutes.ago
      reviewable.update!(created_at: time)
      expect(subject[:created_at]).to eq(time)
    end
  end
end
