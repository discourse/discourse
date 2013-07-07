# encoding: UTF-8

require 'spec_helper'
require_dependency 'post_destroyer'

describe TopicStatusUpdate do
  it "avoids notifying on automatically closed topics" do
    # TODO: TopicStatusUpdate should supress message bus updates from the users it "pretends to read"
    user = Fabricate(:user)
    post = PostCreator.create(user,
      raw: "this is a test post 123 this is a test post",
      title: "hello world title",
    )
    # TODO needed so counts sync up,
    #   PostCreator really should not give back out-of-date Topic
    post.topic.reload

    # TODO: also annoying PostTiming is not logged
    PostTiming.create!(topic_id: post.topic_id, user_id: user.id, post_number: 1, msecs: 0)

    admin = Fabricate(:admin)
    TopicStatusUpdate.new(post.topic, admin).update!("autoclosed", true)

    post.topic.posts.count.should == 2

    tu = TopicUser.where(user_id: user.id).first
    tu.last_read_post_number.should == 2
  end
end
