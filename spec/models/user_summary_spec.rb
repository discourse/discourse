# frozen_string_literal: true

require 'rails_helper'

describe UserSummary do

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

  it "does not include summaries with no clicks" do
    post = Fabricate(:post, raw: "[example](https://example.com)")
    TopicLink.extract_from(post)
    summary = UserSummary.new(post.user, Guardian.new)
    expect(summary.links.length).to eq(0)
  end
end
