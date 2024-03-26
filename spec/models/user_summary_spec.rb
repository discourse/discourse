# frozen_string_literal: true

RSpec.describe UserSummary do
  it "produces secure summaries" do
    topic = create_post.topic
    user = topic.user
    _reply = create_post(user: topic.user, topic: topic)

    summary = UserSummary.new(user, Guardian.new)

    expect(summary.topics.length).to eq(1)
    expect(summary.replies.length).to eq(1)
    expect(summary.top_categories.length).to eq(1)
    expect(summary.top_categories.first[:topic_count]).to eq(1)
    expect(summary.top_categories.first[:post_count]).to eq(1)

    topic.update_columns(deleted_at: Time.now)

    expect(summary.topics.length).to eq(0)
    expect(summary.replies.length).to eq(0)
    expect(summary.top_categories.length).to eq(0)

    topic.update_columns(deleted_at: nil, visible: false)

    expect(summary.topics.length).to eq(0)
    expect(summary.replies.length).to eq(0)
    expect(summary.top_categories.length).to eq(0)

    category = Fabricate(:category)
    topic.update_columns(category_id: category.id, deleted_at: nil, visible: true)

    category.set_permissions(staff: :full)
    category.save

    expect(summary.topics.length).to eq(0)
    expect(summary.replies.length).to eq(0)
    expect(summary.top_categories.length).to eq(0)
  end

  it "is robust enough to handle bad data" do
    UserActionManager.enable

    liked_post = create_post
    user = Fabricate(:user)
    PostActionCreator.like(user, liked_post)

    users = UserSummary.new(user, Guardian.new).most_liked_users

    expect(users.map(&:id)).to eq([liked_post.user_id])

    # really we should not be corrupting stuff like this
    # but in production dbs this can happens sometimes I guess
    liked_post.user.delete

    users = UserSummary.new(user, Guardian.new).most_liked_users
    expect(users).to eq([])
  end

  it "includes ordered top categories" do
    u = Fabricate(:user)

    UserSummary::MAX_SUMMARY_RESULTS.times do
      c = Fabricate(:category)
      t = Fabricate(:topic, category: c, user: u)
      Fabricate(:post, user: u, topic: t)
    end

    top_category = Fabricate(:category)
    t = Fabricate(:topic, category: top_category, user: u)
    Fabricate(:post, user: u, topic: t)
    Fabricate(:post, user: u, topic: t)

    summary = UserSummary.new(u, Guardian.new)

    expect(summary.top_categories.length).to eq(UserSummary::MAX_SUMMARY_RESULTS)
    expect(summary.top_categories.first[:id]).to eq(top_category.id)
  end

  it "excludes moderator action posts" do
    topic = create_post.topic
    user = topic.user
    create_post(user: user, topic: topic)
    Fabricate(:small_action, topic: topic, user: user)

    summary = UserSummary.new(user, Guardian.new)

    expect(summary.topics.length).to eq(1)
    expect(summary.replies.length).to eq(1)
    expect(summary.top_categories.length).to eq(1)
    expect(summary.top_categories.first[:topic_count]).to eq(1)
    expect(summary.top_categories.first[:post_count]).to eq(1)
  end

  it "returns the most replied to users" do
    topic1 = create_post.topic
    topic1_post = create_post(topic: topic1)
    topic1_reply =
      create_post(topic: topic1, reply_to_post_number: topic1_post.post_number, user: topic1.user)

    # Create a second topic by the same user as topic1
    topic2 = create_post(user: topic1.user).topic
    topic2_post = create_post(topic: topic2)
    topic2_reply =
      create_post(topic: topic2, reply_to_post_number: topic2_post.post_number, user: topic2.user)

    # Don't include replies to whispers
    topic3 = create_post(user: topic1.user).topic
    topic3_post = create_post(topic: topic3, post_type: Post.types[:whisper])
    topic3_reply =
      create_post(topic: topic3, reply_to_post_number: topic3_post.post_number, user: topic3.user)

    # Don't include replies to private messages
    replied_to_user = Fabricate(:user)
    topic4 =
      create_post(
        user: topic1.user,
        archetype: Archetype.private_message,
        target_usernames: [replied_to_user.username],
      ).topic
    topic4_post = create_post(topic: topic4, user: replied_to_user)
    topic4_reply =
      create_post(topic: topic4, reply_to_post_number: topic4_post.post_number, user: topic4.user)

    user_summary = UserSummary.new(topic1.user, Guardian.new(topic1.user))
    most_replied_to_users = user_summary.most_replied_to_users

    counts =
      most_replied_to_users
        .index_by { |user_with_count| user_with_count[:id] }
        .transform_values { |c| c[:count] }

    expect(counts).to eq({ topic1_post.user_id => 1, topic2_post.user_id => 1 })
  end
end
