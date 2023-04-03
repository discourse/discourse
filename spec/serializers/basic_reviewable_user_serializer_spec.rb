# frozen_string_literal: true

describe BasicReviewableUserSerializer do
  fab!(:user) { Fabricate(:user) }

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

  subject { described_class.new(reviewable, root: false).as_json }

  include_examples "basic reviewable attributes"

  describe "#username" do
    it "equals the username in the reviewable's payload" do
      expect(subject[:username]).to eq(user.username)
    end
  end
end
