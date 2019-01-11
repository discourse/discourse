require 'rails_helper'

describe UserSummarySerializer do
  it "returns expected data" do
    UserActionCreator.enable
    user = Fabricate(:user)
    liked_post = create_post
    PostAction.act(user, liked_post, PostActionType.types[:like])

    guardian = Guardian.new(user)
    summary = UserSummary.new(user, guardian)
    serializer = UserSummarySerializer.new(summary, scope: guardian, root: false)
    json = serializer.as_json

    expect(json[:likes_given]).to be_present
    expect(json[:likes_received]).to be_present
    expect(json[:posts_read_count]).to be_present
    expect(json[:topic_count]).to be_present
    expect(json[:time_read]).to be_present
    expect(json[:most_liked_users][0][:count]).to be_present
    expect(json[:most_liked_users][0][:username]).to be_present
    expect(json[:most_liked_users][0][:avatar_template]).to be_present
  end
end
