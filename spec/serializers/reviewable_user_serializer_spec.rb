# frozen_string_literal: true

RSpec.describe ReviewableUserSerializer do
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }
  let(:moderator) { Fabricate(:moderator) }
  let(:reviewable) { Reviewable.find_by(target: user) }

  before do
    SiteSetting.must_approve_users = true
    Jobs::CreateUserReviewable.new.execute(user_id: user.id)
  end

  it "includes the user fields for review" do
    json = ReviewableUserSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
    expect(json[:user_id]).to eq(reviewable.target_id)
    expect(json[:payload]["username"]).to eq(user.username)
    expect(json[:payload]["email"]).to eq(user.email)
    expect(json[:payload]["name"]).to eq(user.name)
    expect(json[:topic_url]).to be_blank
  end

  it "excludes the email user field for moderators" do
    json =
      ReviewableUserSerializer.new(reviewable, scope: Guardian.new(moderator), root: nil).as_json
    expect(json[:user_id]).to eq(reviewable.target_id)
    expect(json[:payload]["username"]).to eq(user.username)
    expect(json[:payload]["email"]).to eq(nil)
    expect(json[:payload]["name"]).to eq(user.name)
    expect(json[:topic_url]).to be_blank
  end

  it "includes the email user field for moderators if enabled" do
    SiteSetting.moderators_view_emails = true

    json =
      ReviewableUserSerializer.new(reviewable, scope: Guardian.new(moderator), root: nil).as_json
    expect(json[:user_id]).to eq(reviewable.target_id)
    expect(json[:payload]["username"]).to eq(user.username)
    expect(json[:payload]["email"]).to eq(user.email)
    expect(json[:payload]["name"]).to eq(user.name)
    expect(json[:topic_url]).to be_blank
  end
end
