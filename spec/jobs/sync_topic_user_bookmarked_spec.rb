# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::SyncTopicUserBookmarked do
  it "corrects all topic_users.bookmarked records for the topic" do
    topic = Fabricate(:topic)
    Fabricate(:post, topic: topic)
    Fabricate(:post, topic: topic)
    Fabricate(:post, topic: topic)

    tu1 = Fabricate(:topic_user, topic: topic, bookmarked: false)
    tu2 = Fabricate(:topic_user, topic: topic, bookmarked: false)
    tu3 = Fabricate(:topic_user, topic: topic, bookmarked: true)
    tu4 = Fabricate(:topic_user, topic: topic, bookmarked: true)
    tu5 = Fabricate(:topic_user, bookmarked: false)

    Fabricate(:bookmark, user: tu1.user, topic: topic, post: topic.posts.sample)
    Fabricate(:bookmark, user: tu4.user, topic: topic, post: topic.posts.sample)

    subject.execute(topic_id: topic.id)

    expect(tu1.reload.bookmarked).to eq(true)
    expect(tu2.reload.bookmarked).to eq(false)
    expect(tu3.reload.bookmarked).to eq(false)
    expect(tu4.reload.bookmarked).to eq(true)
    expect(tu5.reload.bookmarked).to eq(false)
  end

  it "does not consider topic as bookmarked if the bookmarked post is deleted" do
    topic = Fabricate(:topic)
    post1 = Fabricate(:post, topic: topic)

    tu1 = Fabricate(:topic_user, topic: topic, bookmarked: false)
    tu2 = Fabricate(:topic_user, topic: topic, bookmarked: true)

    Fabricate(:bookmark, user: tu1.user, topic: topic, post: post1)
    Fabricate(:bookmark, user: tu2.user, topic: topic, post: post1)

    post1.trash!

    subject.execute(topic_id: topic.id)

    expect(tu1.reload.bookmarked).to eq(false)
    expect(tu2.reload.bookmarked).to eq(false)
  end

  it "works when no topic id is provided (runs for all topics)" do
    topic = Fabricate(:topic)
    Fabricate(:post, topic: topic)
    Fabricate(:post, topic: topic)
    Fabricate(:post, topic: topic)

    tu1 = Fabricate(:topic_user, topic: topic, bookmarked: false)
    tu2 = Fabricate(:topic_user, topic: topic, bookmarked: false)
    tu3 = Fabricate(:topic_user, topic: topic, bookmarked: true)
    tu4 = Fabricate(:topic_user, topic: topic, bookmarked: true)
    tu5 = Fabricate(:topic_user, bookmarked: false)

    Fabricate(:bookmark, user: tu1.user, topic: topic, post: topic.posts.sample)
    Fabricate(:bookmark, user: tu4.user, topic: topic, post: topic.posts.sample)

    subject.execute

    expect(tu1.reload.bookmarked).to eq(true)
    expect(tu2.reload.bookmarked).to eq(false)
    expect(tu3.reload.bookmarked).to eq(false)
    expect(tu4.reload.bookmarked).to eq(true)
    expect(tu5.reload.bookmarked).to eq(false)
  end
end
