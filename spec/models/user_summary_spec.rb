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
end
