require 'spec_helper'

describe PollPlugin::PollController, type: :controller do
  let(:topic) { create_topic(title: "Poll: Chitoge vs Onodera") }
  let(:post) { create_post(topic: topic, raw: "Pick one.\n\n[poll]\n* Chitoge\n* Onodera\n[/poll]") }
  let(:user1) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }

  it "should return 403 if no user is logged in" do
    xhr :put, :vote, post_id: post.id, option: "Chitoge", use_route: :poll
    response.should be_forbidden
  end

  it "should return 400 if post_id or invalid option is not specified" do
    log_in_user user1
    xhr :put, :vote, use_route: :poll
    response.status.should eq(400)
    xhr :put, :vote, post_id: post.id, use_route: :poll
    response.status.should eq(400)
    xhr :put, :vote, option: "Chitoge", use_route: :poll
    response.status.should eq(400)
    xhr :put, :vote, post_id: post.id, option: "Tsugumi", use_route: :poll
    response.status.should eq(400)
  end

  it "should return 400 if post_id doesn't correspond to a poll post" do
    log_in_user user1
    post2 = create_post(topic: topic, raw: "Generic reply")
    xhr :put, :vote, post_id: post2.id, option: "Chitoge", use_route: :poll
    response.status.should eq(400)
  end

  it "should save votes correctly" do
    log_in_user user1
    xhr :put, :vote, post_id: post.id, option: "Chitoge", use_route: :poll
    PollPlugin::Poll.new(post).get_vote(user1).should eq("Chitoge")

    log_in_user user2
    xhr :put, :vote, post_id: post.id, option: "Onodera", use_route: :poll
    PollPlugin::Poll.new(post).get_vote(user2).should eq("Onodera")

    PollPlugin::Poll.new(post).details["Chitoge"].should eq(1)
    PollPlugin::Poll.new(post).details["Onodera"].should eq(1)

    xhr :put, :vote, post_id: post.id, option: "Chitoge", use_route: :poll
    PollPlugin::Poll.new(post).get_vote(user2).should eq("Chitoge")

    PollPlugin::Poll.new(post).details["Chitoge"].should eq(2)
    PollPlugin::Poll.new(post).details["Onodera"].should eq(0)
  end
end
