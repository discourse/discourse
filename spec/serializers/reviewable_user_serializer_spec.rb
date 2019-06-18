# frozen_string_literal: true

require 'rails_helper'

describe ReviewableUserSerializer do

  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  it "includes the user fields for review" do
    SiteSetting.must_approve_users = true
    Jobs::CreateUserReviewable.new.execute(user_id: user.id)
    reviewable = Reviewable.find_by(target: user)

    json = ReviewableUserSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
    expect(json[:user_id]).to eq(reviewable.target_id)
    expect(json[:payload]['username']).to eq(user.username)
    expect(json[:payload]['email']).to eq(user.email)
    expect(json[:payload]['name']).to eq(user.name)
    expect(json[:topic_url]).to be_blank
  end

end
