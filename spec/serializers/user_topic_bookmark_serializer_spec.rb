# frozen_string_literal: true

RSpec.describe UserTopicBookmarkSerializer do
  before do
    SiteSetting.use_polymorphic_bookmarks = true
  end

  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:post) { Fabricate(:post, topic: topic) }
  let!(:bookmark) { Fabricate(:bookmark, name: 'Test', user: user, bookmarkable: topic) }

  it "uses the last_read_post_number + 1 for the bookmarks excerpt" do
    next_unread_post = Fabricate(:post_with_long_raw_content, topic: bookmark.bookmarkable)
    Fabricate(:post_with_external_links, topic: bookmark.bookmarkable)
    bookmark.reload
    TopicUser.change(user.id, bookmark.bookmarkable.id, { last_read_post_number: post.post_number })
    serializer = UserTopicBookmarkSerializer.new(bookmark, topic, scope: Guardian.new(user))
    expect(serializer.excerpt).to eq(PrettyText.excerpt(next_unread_post.cooked, 300, keep_emoji_images: true))
  end

  it "does not use a small post for the last unread cooked post" do
    small_action_post = Fabricate(:small_action, topic: bookmark.bookmarkable)
    next_unread_post = Fabricate(:post_with_long_raw_content, topic: bookmark.bookmarkable)
    Fabricate(:post_with_external_links, topic: bookmark.bookmarkable)
    bookmark.reload
    TopicUser.change(user.id, bookmark.bookmarkable.id, { last_read_post_number: post.post_number })
    serializer = UserTopicBookmarkSerializer.new(bookmark, topic, scope: Guardian.new(user))
    expect(serializer.excerpt).to eq(PrettyText.excerpt(next_unread_post.cooked, 300, keep_emoji_images: true))
  end

  it "handles the last read post in the topic being a small post by getting the last read regular post" do
    last_regular_post = Fabricate(:post_with_long_raw_content, topic: bookmark.bookmarkable)
    small_action_post = Fabricate(:small_action, topic: bookmark.bookmarkable)
    bookmark.reload
    TopicUser.change(user.id, bookmark.bookmarkable.id, { last_read_post_number: small_action_post.post_number })
    serializer = UserTopicBookmarkSerializer.new(bookmark, topic, scope: Guardian.new(user))
    expect(serializer.cooked).to eq(last_regular_post.cooked)
    expect(serializer.excerpt).to eq(PrettyText.excerpt(last_regular_post.cooked, 300, keep_emoji_images: true))
  end
end
