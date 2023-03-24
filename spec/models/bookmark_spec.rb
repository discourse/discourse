# frozen_string_literal: true

RSpec.describe Bookmark do
  fab!(:post) { Fabricate(:post) }

  describe "Validations" do
    after { DiscoursePluginRegistry.reset! }

    it "does not allow a user to create a bookmark with only one polymorphic column" do
      user = Fabricate(:user)
      bm = Bookmark.create(bookmarkable_id: post.id, user: user)
      expect(bm.errors.full_messages).to include(
        I18n.t("bookmarks.errors.bookmarkable_id_type_required"),
      )
      bm = Bookmark.create(bookmarkable_type: "Post", user: user)
      expect(bm.errors.full_messages).to include(
        I18n.t("bookmarks.errors.bookmarkable_id_type_required"),
      )
      bm = Bookmark.create(bookmarkable_type: "Post", bookmarkable_id: post.id, user: user)
      expect(bm.errors.full_messages).to be_empty
    end

    it "does not allow a user to create a bookmark for the same record more than once" do
      user = Fabricate(:user)
      Bookmark.create(bookmarkable_type: "Post", bookmarkable_id: post.id, user: user)
      bm = Bookmark.create(bookmarkable_type: "Post", bookmarkable_id: post.id, user: user)
      expect(bm.errors.full_messages).to include(
        I18n.t("bookmarks.errors.already_bookmarked", type: "Post"),
      )
    end

    it "does not allow a user to create a bookmarkable for a type that has not been registered" do
      user = Fabricate(:user)
      bm = Bookmark.create(bookmarkable_type: "User", bookmarkable: Fabricate(:user), user: user)
      expect(bm.errors.full_messages).to include(
        I18n.t("bookmarks.errors.invalid_bookmarkable", type: "User"),
      )
      register_test_bookmarkable
      expect(bm.valid?).to eq(true)
    end
  end

  describe "#cleanup!" do
    it "deletes bookmarks attached to a deleted post which has been deleted for > 3 days" do
      bookmark = Fabricate(:bookmark, bookmarkable: post)
      bookmark2 = Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: post.topic))
      post.trash!
      post.update(deleted_at: 4.days.ago)
      Bookmark.cleanup!
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark2.id)).to eq(bookmark2)
    end

    it "runs a SyncTopicUserBookmarked job for all deleted bookmark unique topics to make sure topic_user.bookmarked is in sync" do
      post2 = Fabricate(:post)
      bookmark = Fabricate(:bookmark, bookmarkable: post)
      bookmark2 = Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: post.topic))
      bookmark3 = Fabricate(:bookmark, bookmarkable: post2)
      bookmark4 = Fabricate(:bookmark, bookmarkable: post2)
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

    it "deletes bookmarks attached via a post to a deleted topic which has been deleted for > 3 days" do
      bookmark = Fabricate(:bookmark, bookmarkable: post)
      bookmark2 = Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: post.topic))
      bookmark3 = Fabricate(:bookmark)
      post.topic.trash!
      post.topic.update(deleted_at: 4.days.ago)
      Bookmark.cleanup!
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark2.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark3.id)).to eq(bookmark3)
      expect_job_enqueued(job: :sync_topic_user_bookmarked, args: { topic_id: post.topic_id })
    end

    it "deletes bookmarks attached via the topic to a deleted topic which has been deleted for > 3 days" do
      topic = Fabricate(:topic)
      bookmark = Fabricate(:bookmark, bookmarkable: topic)
      bookmark2 = Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: topic))
      bookmark3 = Fabricate(:bookmark)
      topic.trash!
      topic.update(deleted_at: 4.days.ago)
      Bookmark.cleanup!
      expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark2.id)).to eq(nil)
      expect(Bookmark.find_by(id: bookmark3.id)).to eq(bookmark3)
      expect_job_enqueued(job: :sync_topic_user_bookmarked, args: { topic_id: topic.id })
    end

    it "does not delete bookmarks attached to posts that are not deleted or that have not met the 3 day grace period" do
      bookmark = Fabricate(:bookmark, bookmarkable: post)
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
      let!(:bookmark4) do
        Fabricate(
          :bookmark,
          bookmarkable: Fabricate(:post, topic: topic_in_category),
          created_at: 3.days.ago,
        )
      end
      let!(:bookmark5) { Fabricate(:bookmark, created_at: 40.days.ago) }

      it "gets the count of bookmarks grouped by date within the last 30 days by default" do
        expect(Bookmark.count_per_day).to eq(
          { 1.day.ago.to_date => 1, 2.days.ago.to_date => 1, 3.days.ago.to_date => 2 },
        )
      end

      it "respects the start_date option" do
        expect(Bookmark.count_per_day(start_date: 1.day.ago - 1.hour)).to eq(
          { 1.day.ago.to_date => 1 },
        )
      end

      it "respects the since_days_ago option" do
        expect(Bookmark.count_per_day(since_days_ago: 2)).to eq({ 1.day.ago.to_date => 1 })
      end

      it "respects the end_date option" do
        expect(Bookmark.count_per_day(end_date: 2.days.ago)).to eq(
          { 2.days.ago.to_date => 1, 3.days.ago.to_date => 2 },
        )
      end

      it "respects the category_id option" do
        expect(Bookmark.count_per_day(category_id: category.id)).to eq({ 3.days.ago.to_date => 1 })
      end

      it "does not include deleted posts or topics" do
        bookmark4.bookmarkable.trash!
        expect(Bookmark.count_per_day(category_id: category.id)).to eq({})
        bookmark4.bookmarkable.recover!
        bookmark4.bookmarkable.topic.trash!
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
