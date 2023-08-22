# frozen_string_literal: true

RSpec.describe Jobs::SyncTopicUserBookmarked do
  subject(:job) { described_class.new }

  fab!(:topic) { Fabricate(:topic) }
  fab!(:post1) { Fabricate(:post, topic: topic) }
  fab!(:post2) { Fabricate(:post, topic: topic) }
  fab!(:post3) { Fabricate(:post, topic: topic) }

  fab!(:tu1) { Fabricate(:topic_user, topic: topic, bookmarked: false) }
  fab!(:tu2) { Fabricate(:topic_user, topic: topic, bookmarked: false) }
  fab!(:tu3) { Fabricate(:topic_user, topic: topic, bookmarked: true) }
  fab!(:tu4) { Fabricate(:topic_user, topic: topic, bookmarked: true) }
  fab!(:tu5) { Fabricate(:topic_user, topic: topic, bookmarked: true) }

  it "corrects all topic_users.bookmarked records for the topic" do
    Fabricate(:bookmark, user: tu1.user, bookmarkable: topic.posts.sample)
    Fabricate(:bookmark, user: tu4.user, bookmarkable: topic.posts.sample)

    job.execute(topic_id: topic.id)

    expect(tu1.reload.bookmarked).to eq(true)
    expect(tu2.reload.bookmarked).to eq(false)
    expect(tu3.reload.bookmarked).to eq(false)
    expect(tu4.reload.bookmarked).to eq(true)
    expect(tu5.reload.bookmarked).to eq(false)
  end

  it "does not consider topic as bookmarked if the bookmarked post is deleted" do
    Fabricate(:bookmark, user: tu1.user, bookmarkable: post1)
    Fabricate(:bookmark, user: tu2.user, bookmarkable: post1)

    post1.trash!

    job.execute(topic_id: topic.id)

    expect(tu1.reload.bookmarked).to eq(false)
    expect(tu2.reload.bookmarked).to eq(false)
  end

  it "works when no topic id is provided (runs for all topics)" do
    Fabricate(:bookmark, user: tu1.user, bookmarkable: topic.posts.sample)
    Fabricate(:bookmark, user: tu4.user, bookmarkable: topic.posts.sample)

    job.execute

    expect(tu1.reload.bookmarked).to eq(true)
    expect(tu2.reload.bookmarked).to eq(false)
    expect(tu3.reload.bookmarked).to eq(false)
    expect(tu4.reload.bookmarked).to eq(true)
    expect(tu5.reload.bookmarked).to eq(false)
  end
end
