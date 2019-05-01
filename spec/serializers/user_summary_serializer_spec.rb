# frozen_string_literal: true

require 'rails_helper'

describe UserSummarySerializer do
  it "returns expected data" do
    UserActionManager.enable
    user = Fabricate(:user)
    liked_user = Fabricate(:user, name: "John Doe", username: "john_doe")
    liked_post = create_post(user: liked_user)
    PostActionCreator.like(user, liked_post)

    guardian = Guardian.new(user)
    summary = UserSummary.new(user, guardian)
    serializer = UserSummarySerializer.new(summary, scope: guardian, root: false)
    json = serializer.as_json

    expect(json[:likes_given]).to eq(1)
    expect(json[:likes_received]).to be_present
    expect(json[:posts_read_count]).to be_present
    expect(json[:topic_count]).to be_present
    expect(json[:time_read]).to be_present
    expect(json[:most_liked_users][0][:count]).to eq(1)
    expect(json[:most_liked_users][0][:name]).to eq("John Doe")
    expect(json[:most_liked_users][0][:username]).to eq("john_doe")
    expect(json[:most_liked_users][0][:avatar_template]).to eq(liked_user.avatar_template)

    # do not include full name if disabled
    SiteSetting.enable_names = false
    expect(serializer.as_json[:most_liked_users][0][:name]).to eq(nil)
  end
end
