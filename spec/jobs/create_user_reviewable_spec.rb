# frozen_string_literal: true

require 'rails_helper'

describe Jobs::CreateUserReviewable do

  let(:user) { Fabricate(:user) }

  it "creates the reviewable" do
    SiteSetting.must_approve_users = true
    described_class.new.execute(user_id: user.id)

    reviewable = Reviewable.find_by(target: user)
    expect(reviewable).to be_present
    expect(reviewable.pending?).to eq(true)
    expect(reviewable.payload['username']).to eq(user.username)
    expect(reviewable.payload['name']).to eq(user.name)
    expect(reviewable.payload['email']).to eq(user.email)
  end

  it "should not raise an error if there is a reviewable already" do
    SiteSetting.must_approve_users = true
    described_class.new.execute(user_id: user.id)
    described_class.new.execute(user_id: user.id)

    reviewable = Reviewable.find_by(target: user)
    expect(reviewable.reviewable_scores.size).to eq(1)
  end

  describe "reasons" do
    it "does nothing if there's no reason" do
      described_class.new.execute(user_id: user.id)
      expect(Reviewable.find_by(target: user)).to be_blank
    end

    it "adds must_approve_users if enabled" do
      SiteSetting.must_approve_users = true
      described_class.new.execute(user_id: user.id)
      reviewable = Reviewable.find_by(target: user)
      score = reviewable.reviewable_scores.first
      expect(score).to be_present
      expect(score.reason).to eq('must_approve_users')
    end

    it "adds invite_only if enabled" do
      SiteSetting.invite_only = true
      described_class.new.execute(user_id: user.id)
      reviewable = Reviewable.find_by(target: user)
      score = reviewable.reviewable_scores.first
      expect(score).to be_present
      expect(score.reason).to eq('invite_only')
    end
  end

end
