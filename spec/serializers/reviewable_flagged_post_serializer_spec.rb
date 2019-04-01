require 'rails_helper'

describe ReviewableFlaggedPostSerializer do

  let(:admin) { Fabricate(:admin) }

  it "includes the user fields for review" do
    p0 = Fabricate(:post)
    reviewable = PostActionCreator.spam(Fabricate(:user), p0).reviewable
    json = ReviewableFlaggedPostSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
    expect(json[:cooked]).to be_present
    expect(json[:raw]).to be_present
    expect(json[:topic_url]).to eq(p0.url)
  end

end
