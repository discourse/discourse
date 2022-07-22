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
        website: "ff.website.com"
      }
    )
  end

  def get_json
    described_class.new(reviewable, root: false).as_json
  end

  it "includes username" do
    expect(get_json[:username]).to eq(user.username)
  end

  it "is a subclass of BasicReviewableSerializer" do
    expect(described_class).to be < BasicReviewableSerializer
  end
end
