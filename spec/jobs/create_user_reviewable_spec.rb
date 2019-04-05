require 'rails_helper'
require_dependency 'jobs/regular/create_user_reviewable'

describe Jobs::CreateUserReviewable do

  let(:user) { Fabricate(:user) }

  it "creates the reviewable" do
    described_class.new.execute(user_id: user.id)

    reviewable = Reviewable.find_by(target: user)
    expect(reviewable).to be_present
    expect(reviewable.pending?).to eq(true)
    expect(reviewable.reviewable_scores).to be_present
    expect(reviewable.payload['username']).to eq(user.username)
    expect(reviewable.payload['name']).to eq(user.name)
    expect(reviewable.payload['email']).to eq(user.email)
  end
end
