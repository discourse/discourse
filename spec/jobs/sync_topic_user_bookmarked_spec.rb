# frozen_string_literal: true

RSpec.describe Jobs::SyncTopicUserBookmarked do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  def execute
    described_class.new.execute(topic_id: topic.id)
  end

  it "sets bookmarked to false when no bookmarks exist for the topic" do
    tu = Fabricate(:topic_user, topic:, bookmarked: true)

    execute

    expect(tu.reload.bookmarked).to eq(false)
  end

  it "does not count bookmarks on deleted posts" do
    tu = Fabricate(:topic_user, topic:, bookmarked: true)
    Fabricate(:bookmark, user: tu.user, bookmarkable: post)
    post.trash!

    execute

    expect(tu.reload.bookmarked).to eq(false)
  end

  it "sets bookmarked to true when user has both a Topic and a Post bookmark" do
    tu = Fabricate(:topic_user, topic:, bookmarked: false)
    Fabricate(:bookmark, user: tu.user, bookmarkable: topic)
    Fabricate(:bookmark, user: tu.user, bookmarkable: post)

    execute

    expect(tu.reload.bookmarked).to eq(true)
  end

  it "does not count bookmarks from other topics" do
    other_post = Fabricate(:post)
    tu = Fabricate(:topic_user, topic:, bookmarked: true)
    Fabricate(:bookmark, user: tu.user, bookmarkable: other_post)

    execute

    expect(tu.reload.bookmarked).to eq(false)
  end

  it "correctly syncs multiple users with different bookmark states" do
    bookmarked_via_post = Fabricate(:topic_user, topic:, bookmarked: false)
    bookmarked_via_topic = Fabricate(:topic_user, topic:, bookmarked: false)
    stale = Fabricate(:topic_user, topic:, bookmarked: true)
    no_bookmark = Fabricate(:topic_user, topic:, bookmarked: false)

    Fabricate(:bookmark, user: bookmarked_via_post.user, bookmarkable: post)
    Fabricate(:bookmark, user: bookmarked_via_topic.user, bookmarkable: topic)

    execute

    expect(bookmarked_via_post.reload.bookmarked).to eq(true)
    expect(bookmarked_via_topic.reload.bookmarked).to eq(true)
    expect(stale.reload.bookmarked).to eq(false)
    expect(no_bookmark.reload.bookmarked).to eq(false)
  end
end
