# frozen_string_literal: true

describe Bookmark do
  fab!(:post) { Fabricate(:post) }

  context "validations" do
    it "does not allow user to bookmark a post twice, enforces unique bookmark per post, user, and for_topic" do
      bookmark = Fabricate(:bookmark, post: post)
      user = bookmark.user

      bookmark_2 = Fabricate.build(:bookmark,
        post: post,
        user: user
      )

      expect(bookmark_2.valid?).to eq(false)
    end

    it "allows a user to bookmark a post twice if it is the first post and for_topic is different" do
      post.update!(post_number: 1)
      bookmark = Fabricate(:bookmark, post: post, for_topic: false)
      user = bookmark.user

      bookmark_2 = Fabricate(:bookmark,
        post: post,
        user: user,
        for_topic: true
      )

      expect(bookmark_2.valid?).to eq(true)

      bookmark_3 = Fabricate.build(:bookmark,
        post: post,
        user: user,
        for_topic: true
      )

      expect(bookmark_3.valid?).to eq(false)
    end
  end

  describe "#find_for_topic_by_user" do
    it "gets the for_topic bookmark for a user for a specific topic" do
      user = Fabricate(:user)
      post.update!(post_number: 1)
      bookmark = Fabricate(:bookmark, user: user)
      bookmark_2 = Fabricate(:bookmark, user: user, post: post, for_topic: true)
      expect(Bookmark.find_for_topic_by_user(post.topic_id, user.id)).to eq(bookmark_2)
      bookmark_2.update!(for_topic: false)
      expect(Bookmark.find_for_topic_by_user(post.topic_id, user.id)).to eq(nil)
    end
  end

  describe "#cleanup!" do
    it "deletes bookmarks attached to a deleted post which has been deleted for > 3 days" do
      bookmark = Fabricate(:bookmark, post: post)
      bookmark2 = Fabricate(:bookmark, post: Fabricate(:post, topic: post.topic))
      post.trash!
      post.update(deleted_at: 4.days.ago)
      Bookmark.cleanup!
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark2.id)).to eq(bookmark2)
    end

    it "runs a SyncTopicUserBookmarked job for all deleted bookmark unique topics to make sure topic_user.bookmarked is in sync" do
      post2 = Fabricate(:post)
      bookmark = Fabricate(:bookmark, post: post)
      bookmark2 = Fabricate(:bookmark, post: Fabricate(:post, topic: post.topic))
      bookmark3 = Fabricate(:bookmark, post: post2)
      bookmark4 = Fabricate(:bookmark, post: post2)
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
      bookmark = Fabricate(:bookmark, post: post)
      bookmark2 = Fabricate(:bookmark, post: Fabricate(:post, topic: post.topic))
      bookmark3 = Fabricate(:bookmark)
      post.topic.trash!
      post.topic.update(deleted_at: 4.days.ago)
      Bookmark.cleanup!
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark2.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark3.id)).to eq(bookmark3)
    end

    it "does not delete bookmarks attached to posts that are not deleted or that have not met the 3 day grace period" do
      bookmark = Fabricate(:bookmark, post: post)
      bookmark2 = Fabricate(:bookmark)
      Bookmark.cleanup!
      expect(Bookmark.find(bookmark.id)).to eq(bookmark)
      post.trash!
      Bookmark.cleanup!
      expect(Bookmark.find(bookmark.id)).to eq(bookmark)
      expect(Bookmark.find_by(id: bookmark2.id)).to eq(bookmark2)
    end

    describe "#count_per_day" do
      let(:category) { Fabricate(:category) }
      let(:topic_in_category) { Fabricate(:topic, category: category) }
      let!(:bookmark1) { Fabricate(:bookmark, created_at: 1.day.ago) }
      let!(:bookmark2) { Fabricate(:bookmark, created_at: 2.days.ago) }
      let!(:bookmark3) { Fabricate(:bookmark, created_at: 3.days.ago) }
      let!(:bookmark4) { Fabricate(:bookmark, post: Fabricate(:post, topic: topic_in_category), created_at: 3.days.ago) }
      let!(:bookmark5) { Fabricate(:bookmark, created_at: 40.days.ago) }

      it "gets the count of bookmarks grouped by date within the last 30 days by default" do
        expect(Bookmark.count_per_day).to eq({
          1.day.ago.to_date => 1,
          2.days.ago.to_date => 1,
          3.days.ago.to_date => 2
        })
      end

      it "respects the start_date option" do
        expect(Bookmark.count_per_day(start_date: 1.day.ago - 1.hour)).to eq({
          1.day.ago.to_date => 1,
        })
      end

      it "respects the since_days_ago option" do
        expect(Bookmark.count_per_day(since_days_ago: 2)).to eq({
          1.day.ago.to_date => 1,
        })
      end

      it "respects the end_date option" do
        expect(Bookmark.count_per_day(end_date: 2.days.ago)).to eq({
          2.days.ago.to_date => 1,
          3.days.ago.to_date => 2,
        })
      end

      it "respects the category_id option" do
        expect(Bookmark.count_per_day(category_id: category.id)).to eq({
          3.days.ago.to_date => 1,
        })
      end

      it "does not include deleted posts or topics" do
        bookmark4.post.trash!
        expect(Bookmark.count_per_day(category_id: category.id)).to eq({})
        bookmark4.post.recover!
        bookmark4.topic.trash!
        expect(Bookmark.count_per_day(category_id: category.id)).to eq({})
      end
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
