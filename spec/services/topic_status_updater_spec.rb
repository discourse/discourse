# encoding: UTF-8

require 'rails_helper'
require_dependency 'post_destroyer'

# TODO - test pinning, create_moderator_post

describe TopicStatusUpdater do

  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  it "avoids notifying on automatically closed topics" do
    # TODO: TopicStatusUpdater should suppress message bus updates from the users it "pretends to read"
    post = PostCreator.create(user,
      raw: "this is a test post 123 this is a test post",
      title: "hello world title",
    )
    # TODO needed so counts sync up, PostCreator really should not give back out-of-date Topic
    post.topic.set_or_create_timer(TopicTimer.types[:close], '10')
    post.topic.reload

    TopicStatusUpdater.new(post.topic, admin).update!("autoclosed", true)

    expect(post.topic.posts.count).to eq(2)

    tu = TopicUser.find_by(user_id: user.id)
    expect(tu.last_read_post_number).to eq(2)
  end

  it "adds an autoclosed message" do
    topic = create_topic
    topic.set_or_create_timer(TopicTimer.types[:close], '10')

    TopicStatusUpdater.new(topic, admin).update!("autoclosed", true)

    last_post = topic.posts.last
    expect(last_post.post_type).to eq(Post.types[:small_action])
    expect(last_post.action_code).to eq('autoclosed.enabled')
    expect(last_post.raw).to eq(I18n.t("topic_statuses.autoclosed_enabled_minutes", count: 0))
  end

  it "triggers a DiscourseEvent on close" do
    topic = create_topic

    called = false
    updater = -> (_) { called = true }

    DiscourseEvent.on(:topic_closed, &updater)
    TopicStatusUpdater.new(topic, admin).update!("closed", true)
    DiscourseEvent.off(:topic_closed, &updater)

    expect(topic).to be_closed
    expect(called).to eq(true)
  end

  it "adds an autoclosed message based on last post" do
    topic = create_topic
    Fabricate(:post, topic: topic)

    topic.set_or_create_timer(
      TopicTimer.types[:close], '10', based_on_last_post: true
    )

    TopicStatusUpdater.new(topic, admin).update!("autoclosed", true)

    last_post = topic.posts.last
    expect(last_post.post_type).to eq(Post.types[:small_action])
    expect(last_post.action_code).to eq('autoclosed.enabled')
    expect(last_post.raw).to eq(I18n.t("topic_statuses.autoclosed_enabled_lastpost_hours", count: 10))
  end

  describe "repeat actions" do

    shared_examples "an action that doesn't repeat" do
      it "does not perform the update twice" do
        topic = Fabricate(:topic, status_name => false)
        updated = TopicStatusUpdater.new(topic, admin).update!(status_name, true)
        expect(updated).to eq(true)
        expect(topic.send("#{status_name}?")).to eq(true)

        updated = TopicStatusUpdater.new(topic, admin).update!(status_name, true)
        expect(updated).to eq(false)
        expect(topic.posts.where(post_type: Post.types[:small_action]).count).to eq(1)

        updated = TopicStatusUpdater.new(topic, admin).update!(status_name, false)
        expect(updated).to eq(true)
        expect(topic.send("#{status_name}?")).to eq(false)

        updated = TopicStatusUpdater.new(topic, admin).update!(status_name, false)
        expect(updated).to eq(false)
        expect(topic.posts.where(post_type: Post.types[:small_action]).count).to eq(2)
      end

    end

    it_behaves_like "an action that doesn't repeat" do
      let(:status_name) { "closed" }
    end

    it_behaves_like "an action that doesn't repeat" do
      let(:status_name) { "visible" }
    end

    it_behaves_like "an action that doesn't repeat" do
      let(:status_name) { "archived" }
    end

    it "updates autoclosed" do
      topic = Fabricate(:topic)
      updated = TopicStatusUpdater.new(topic, admin).update!('autoclosed', true)
      expect(updated).to eq(true)
      expect(topic.closed?).to eq(true)

      updated = TopicStatusUpdater.new(topic, admin).update!('autoclosed', true)
      expect(updated).to eq(false)
      expect(topic.posts.where(post_type: Post.types[:small_action]).count).to eq(1)

      updated = TopicStatusUpdater.new(topic, admin).update!('autoclosed', false)
      expect(updated).to eq(true)
      expect(topic.closed?).to eq(false)

      updated = TopicStatusUpdater.new(topic, admin).update!('autoclosed', false)
      expect(updated).to eq(false)
      expect(topic.posts.where(post_type: Post.types[:small_action]).count).to eq(2)
    end

  end
end
