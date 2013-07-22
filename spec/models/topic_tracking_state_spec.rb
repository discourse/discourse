require 'spec_helper'

describe TopicTrackingState do

  let(:user) do
    Fabricate(:user)
  end

  let(:post) do
    create_post
  end

  it "can correctly publish unread" do
    # TODO setup stuff and look at messages
    TopicTrackingState.publish_unread(post)
  end

  it "correctly gets the tracking state" do
    report = TopicTrackingState.report([user.id])
    report.length.should == 0

    new_post = post
    post.topic.notifier.watch_topic!(post.topic.user_id)

    report = TopicTrackingState.report([user.id])

    report.length.should == 1
    row = report[0]

    row.topic_id.should == post.topic_id
    row.highest_post_number.should == 1
    row.last_read_post_number.should be_nil
    row.user_id.should == user.id

    # lets not leak out random users
    TopicTrackingState.report([post.user_id]).should be_empty

    # lets not return anything if we scope on non-existing topic
    TopicTrackingState.report([user.id], post.topic_id + 1).should be_empty

    # when we reply the poster should have an unread row
    create_post(user: user, topic: post.topic)

    report = TopicTrackingState.report([post.user_id, user.id])
    report.length.should == 1

    row = report[0]

    row.topic_id.should == post.topic_id
    row.highest_post_number.should == 2
    row.last_read_post_number.should == 1
    row.user_id.should == post.user_id

    # when we have no permission to see a category, don't show its stats
    category = Fabricate(:category, read_restricted: true)

    post.topic.category_id = category.id
    post.topic.save

    TopicTrackingState.report([post.user_id, user.id]).count.should == 0
  end
end
