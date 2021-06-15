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

    it "runs a SyncTopicUserBookmarked job for all deleted bookmark unique topics to make sure topic_user.bookmarked is in sync" do
      post = Fabricate(:post)
      post2 = Fabricate(:post)
      bookmark = Fabricate(:bookmark, post: post, topic: post.topic)
      bookmark2 = Fabricate(:bookmark, post: Fabricate(:post, topic: post.topic))
      bookmark3 = Fabricate(:bookmark, post: post2, topic: post2.topic)
      bookmark4 = Fabricate(:bookmark, post: post2, topic: post2.topic)
      post.trash!
      post.update(deleted_at: 4.days.ago)
      post2.trash!
      post2.update(deleted_at: 4.days.ago)
      Bookmark.cleanup!
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark2.id)).to eq(bookmark2)
      expect(Bookmark.find_by(id: bookmark3.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark4.id)).to eq(nil)
      expect_job_enqueued(job: :sync_topic_user_bookmarked, args: { topic_id: post.topic_id })
      expect_job_enqueued(job: :sync_topic_user_bookmarked, args: { topic_id: post2.topic_id })
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

    describe "bookmark limits" do
      fab!(:user) { Fabricate(:user) }

      it "does not get the bookmark limit error because it is not creating a new bookmark (for users already over the limit)" do
        Fabricate(:bookmark, user: user)
        Fabricate(:bookmark, user: user)
        last_bookmark = Fabricate(:bookmark, user: user)
        SiteSetting.max_bookmarks_per_user = 2
        expect { last_bookmark.clear_reminder! }.not_to raise_error
      end

      it "gets the bookmark limit error when creating a new bookmark over the limit" do
        Fabricate(:bookmark, user: user)
        Fabricate(:bookmark, user: user)
        SiteSetting.max_bookmarks_per_user = 2
        expect { Fabricate(:bookmark, user: user) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
