# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserBookmarkSerializer do
  let(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post, user: user) }
  let!(:bookmark) { Fabricate(:bookmark, name: 'Test', user: user, post: post, topic: post.topic) }
  let(:bookmark_list) { BookmarkQuery.new(user: bookmark.user).list_all.to_ary }

  it "serializes all properties correctly" do
    s = UserBookmarkSerializer.new(bookmark_list.last)

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
  end

  context "when the topic is deleted" do
    before do
      bookmark.topic.trash!
      bookmark.reload
    end
    it "it has nothing to serialize" do
      expect(bookmark_list).to eq([])
    end
  end

  context "when the post is deleted" do
    before do
      bookmark.post.trash!
      bookmark.reload
    end
    it "it has nothing to serialize" do
      expect(bookmark_list).to eq([])
    end
  end

end
