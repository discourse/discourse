# frozen_string_literal: true

describe BasicReviewableUserSerializer do
  subject(:serializer) { described_class.new(reviewable, root: false).as_json }

  fab!(:user)
  fab!(:reviewable) do
    ReviewableUser.needs_review!(
      target: user,
      created_by: Discourse.system_user,
      payload: {
        username: user.username,
        name: user.name,
        email: user.email,
        bio: "blah whatever",
        website: "ff.website.com",
      },
    )
  end

  include_examples "basic reviewable attributes"

  describe "#username" do
    it "equals the username in the reviewable's payload" do
      expect(serializer[:username]).to eq(user.username)
    end
  end
end
