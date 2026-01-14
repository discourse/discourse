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

  it "includes the scrubbed fields for scrubbed reviewables" do
    reviewable.scrub("reason", Guardian.new(admin))

    json = ReviewableUserSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
    expect(json[:user_id]).to eq(reviewable.target_id)
    expect(json[:payload]["username"]).to eq(nil)
    expect(json[:payload]["email"]).to eq(nil)
    expect(json[:payload]["name"]).to eq(nil)
    expect(json[:payload]["scrubbed_by"]).to eq(admin.username)
    expect(json[:payload]["scrubbed_reason"]).to eq("reason")
    expect(json[:payload]["scrubbed_at"]).to be_present
    expect(json[:topic_url]).to be_blank
  end

  describe "target_user" do
    it "returns nil when there is no target" do
      reviewable = ReviewableUser.new
      json = ReviewableUserSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:target_user]).to be_nil
    end

    it "returns FlaggedUserSerializer when user can see reviewable UI refresh" do
      allow_any_instance_of(Guardian).to receive(:can_see_reviewable_ui_refresh?).and_return(true)

      json = ReviewableUserSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:target_user]).to be_present
      expect(json[:target_user][:id]).to eq(user.id)
      expect(json[:target_user][:username]).to eq(user.username)
    end
  end
end
