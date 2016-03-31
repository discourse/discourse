require 'rails_helper'

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

  it "correctly handles muted categories" do

    user = Fabricate(:user)
    post

    report = TopicTrackingState.report(user.id)
    expect(report.length).to eq(1)

    CategoryUser.create!(user_id: user.id,
                         notification_level: CategoryUser.notification_levels[:muted],
                         category_id: post.topic.category_id
                         )

    create_post(topic_id: post.topic_id)

    report = TopicTrackingState.report(user.id)
    expect(report.length).to eq(0)

    TopicUser.create!(user_id: user.id, topic_id: post.topic_id, last_read_post_number: 1, notification_level: 3)

    report = TopicTrackingState.report(user.id)
    expect(report.length).to eq(1)
  end


  it "correctly handles capping" do
    user = Fabricate(:user)

    post1 = create_post
    Fabricate(:post, topic: post1.topic)

    post2 = create_post
    Fabricate(:post, topic: post2.topic)

    post3 = create_post
    Fabricate(:post, topic: post3.topic)

    tracking = {
      notification_level: TopicUser.notification_levels[:tracking],
      last_read_post_number: 1,
      highest_seen_post_number: 1
    }

    TopicUser.change(user.id, post1.topic_id, tracking)
    TopicUser.change(user.id, post2.topic_id, tracking)
    TopicUser.change(user.id, post3.topic_id, tracking)

    report = TopicTrackingState.report(user.id)
    expect(report.length).to eq(3)

  end

  it "correctly gets the tracking state" do
    report = TopicTrackingState.report(user.id)
    expect(report.length).to eq(0)

    post.topic.notifier.watch_topic!(post.topic.user_id)

    report = TopicTrackingState.report(user.id)

    expect(report.length).to eq(1)
    row = report[0]

    expect(row.topic_id).to eq(post.topic_id)
    expect(row.highest_post_number).to eq(1)
    expect(row.last_read_post_number).to eq(nil)
    expect(row.user_id).to eq(user.id)

    # lets not leak out random users
    expect(TopicTrackingState.report(post.user_id)).to be_empty

    # lets not return anything if we scope on non-existing topic
    expect(TopicTrackingState.report(user.id, post.topic_id + 1)).to be_empty

    # when we reply the poster should have an unread row
    create_post(user: user, topic: post.topic)

    report = TopicTrackingState.report(user.id)
    expect(report.length).to eq(0)

    report = TopicTrackingState.report(post.user_id)
    expect(report.length).to eq(1)

    row = report[0]

    expect(row.topic_id).to eq(post.topic_id)
    expect(row.highest_post_number).to eq(2)
    expect(row.last_read_post_number).to eq(1)
    expect(row.user_id).to eq(post.user_id)

    # when we have no permission to see a category, don't show its stats
    category = Fabricate(:category, read_restricted: true)

    post.topic.category_id = category.id
    post.topic.save

    expect(TopicTrackingState.report(post.user_id)).to be_empty
    expect(TopicTrackingState.report(user.id)).to be_empty
  end
end
