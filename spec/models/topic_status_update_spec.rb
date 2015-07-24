# encoding: UTF-8

require 'spec_helper'
require_dependency 'post_destroyer'

describe TopicStatusUpdate do

  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  it "avoids notifying on automatically closed topics" do
    # TODO: TopicStatusUpdate should supress message bus updates from the users it "pretends to read"
    post = PostCreator.create(user,
      raw: "this is a test post 123 this is a test post",
      title: "hello world title",
    )
    # TODO needed so counts sync up, PostCreator really should not give back out-of-date Topic
    post.topic.reload

    TopicStatusUpdate.new(post.topic, admin).update!("autoclosed", true)

    expect(post.topic.posts.count).to eq(2)

    tu = TopicUser.find_by(user_id: user.id)
    expect(tu.last_read_post_number).to eq(2)
  end

  it "adds an autoclosed message" do
    topic = create_topic

    TopicStatusUpdate.new(topic, admin).update!("autoclosed", true)

    last_post = topic.posts.last
    expect(last_post.post_type).to eq(Post.types[:small_action])
    expect(last_post.action_code).to eq('autoclosed.enabled')
    expect(last_post.raw).to eq(I18n.t("topic_statuses.autoclosed_enabled_minutes", count: 0))
  end

  it "adds an autoclosed message based on last post" do
    topic = create_topic
    topic.auto_close_based_on_last_post = true

    TopicStatusUpdate.new(topic, admin).update!("autoclosed", true)

    last_post = topic.posts.last
    expect(last_post.post_type).to eq(Post.types[:small_action])
    expect(last_post.action_code).to eq('autoclosed.enabled')
    expect(last_post.raw).to eq(I18n.t("topic_statuses.autoclosed_enabled_lastpost_minutes", count: 0))
  end

end
