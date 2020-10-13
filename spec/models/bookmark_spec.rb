# frozen_string_literal: true

require 'rails_helper'

describe Bookmark do
  describe "#cleanup!" do
    it "deletes bookmarks attached to a deleted post which has been deleted for > 3 days" do
      post = Fabricate(:post)
      bookmark = Fabricate(:bookmark, post: post, topic: post.topic)
      bookmark2 = Fabricate(:bookmark, post: Fabricate(:post, topic: post.topic))
      post.trash!
      post.update(deleted_at: 4.days.ago)
      Bookmark.cleanup!
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark2.id)).to eq(bookmark2)
    end

    it "deletes bookmarks attached to a deleted topic which has been deleted for > 3 days" do
      post = Fabricate(:post)
      bookmark = Fabricate(:bookmark, post: post, topic: post.topic)
      bookmark2 = Fabricate(:bookmark, topic: post.topic, post: Fabricate(:post, topic: post.topic))
      bookmark3 = Fabricate(:bookmark)
      post.topic.trash!
      post.topic.update(deleted_at: 4.days.ago)
      Bookmark.cleanup!
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark2.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark3.id)).to eq(bookmark3)
    end

    it "does not delete bookmarks attached to posts that are not deleted or that have not met the 3 day grace period" do
      post = Fabricate(:post)
      bookmark = Fabricate(:bookmark, post: post, topic: post.topic)
      bookmark2 = Fabricate(:bookmark)
      Bookmark.cleanup!
      expect(Bookmark.find(bookmark.id)).to eq(bookmark)
      post.trash!
      Bookmark.cleanup!
      expect(Bookmark.find(bookmark.id)).to eq(bookmark)
      expect(Bookmark.find_by(id: bookmark2.id)).to eq(bookmark2)
    end
  end
end
