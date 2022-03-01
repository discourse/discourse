# frozen_string_literal: true

RSpec.describe UserBookmarkSerializer do
  let(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post, user: user) }
  let!(:bookmark) { Fabricate(:bookmark, name: 'Test', user: user, post: post) }

  it "serializes all properties correctly" do
    s = UserBookmarkSerializer.new(bookmark, scope: Guardian.new(user))

    expect(s.id).to eq(bookmark.id)
    expect(s.created_at).to eq_time(bookmark.created_at)
    expect(s.topic_id).to eq(bookmark.topic_id)
    expect(s.linked_post_number).to eq(bookmark.post.post_number)
    expect(s.post_id).to eq(bookmark.post_id)
    expect(s.name).to eq(bookmark.name)
    expect(s.reminder_at).to eq_time(bookmark.reminder_at)
    expect(s.title).to eq(bookmark.topic.title)
    expect(s.deleted).to eq(false)
    expect(s.hidden).to eq(false)
    expect(s.closed).to eq(false)
    expect(s.archived).to eq(false)
    expect(s.category_id).to eq(bookmark.topic.category_id)
    expect(s.archetype).to eq(bookmark.topic.archetype)
    expect(s.highest_post_number).to eq(1)
    expect(s.bumped_at).to eq_time(bookmark.topic.bumped_at)
    expect(s.slug).to eq(bookmark.topic.slug)
    expect(s.post_user_username).to eq(bookmark.post.user.username)
    expect(s.post_user_name).to eq(bookmark.post.user.name)
    expect(s.post_user_avatar_template).not_to eq(nil)
    expect(s.excerpt).to eq(PrettyText.excerpt(post.cooked, 300, keep_emoji_images: true))
  end

  it "uses the correct highest_post_number column based on whether the user is staff" do
    Fabricate(:post, topic: bookmark.topic)
    Fabricate(:post, topic: bookmark.topic)
    Fabricate(:whisper, topic: bookmark.topic)
    bookmark.reload
    serializer = UserBookmarkSerializer.new(bookmark, scope: Guardian.new(user))

    expect(serializer.highest_post_number).to eq(3)

    user.update!(admin: true)

    expect(serializer.highest_post_number).to eq(4)
  end

  context "for_topic bookmarks" do
    before do
      bookmark.update!(for_topic: true)
    end

    it "uses the last_read_post_number + 1 for the for_topic bookmarks excerpt" do
      next_unread_post = Fabricate(:post_with_long_raw_content, topic: bookmark.topic)
      Fabricate(:post_with_external_links, topic: bookmark.topic)
      bookmark.reload
      TopicUser.change(user.id, bookmark.topic.id, { last_read_post_number: post.post_number })
      serializer = UserBookmarkSerializer.new(bookmark, scope: Guardian.new(user))
      expect(serializer.excerpt).to eq(PrettyText.excerpt(next_unread_post.cooked, 300, keep_emoji_images: true))
    end

    it "does not use a small post for the last unread cooked post" do
      small_action_post = Fabricate(:small_action, topic: bookmark.topic)
      next_unread_post = Fabricate(:post_with_long_raw_content, topic: bookmark.topic)
      Fabricate(:post_with_external_links, topic: bookmark.topic)
      bookmark.reload
      TopicUser.change(user.id, bookmark.topic.id, { last_read_post_number: post.post_number })
      serializer = UserBookmarkSerializer.new(bookmark, scope: Guardian.new(user))
      expect(serializer.excerpt).to eq(PrettyText.excerpt(next_unread_post.cooked, 300, keep_emoji_images: true))
    end

    it "handles the last read post in the topic being a small post by getting the last read regular post" do
      last_regular_post = Fabricate(:post_with_long_raw_content, topic: bookmark.topic)
      small_action_post = Fabricate(:small_action, topic: bookmark.topic)
      bookmark.reload
      TopicUser.change(user.id, bookmark.topic.id, { last_read_post_number: small_action_post.post_number })
      serializer = UserBookmarkSerializer.new(bookmark, scope: Guardian.new(user))
      expect(serializer.cooked).to eq(last_regular_post.cooked)
      expect(serializer.excerpt).to eq(PrettyText.excerpt(last_regular_post.cooked, 300, keep_emoji_images: true))
    end
  end
end
