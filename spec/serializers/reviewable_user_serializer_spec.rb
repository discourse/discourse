require 'rails_helper'

describe ReviewableUserSerializer do

  let(:reviewable) { Fabricate(:reviewable) }
  let(:admin) { Fabricate(:admin) }

  it "includes the user fields for review" do
    json = ReviewableUserSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
    expect(json[:user_id]).to eq(reviewable.target_id)
    expect(json[:username]).to eq(reviewable.target.username)
    expect(json[:email]).to eq(reviewable.target.email)
    expect(json[:name]).to eq(reviewable.target.name)
  end

end
