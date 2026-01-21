# frozen_string_literal: true

RSpec.describe BookmarkQuery do
  fab!(:user)

  def bookmark_query(user: nil, guardian: nil, search_term: nil, per_page: nil)
    BookmarkQuery.new(user: user || self.user, guardian:, search_term:, per_page:)
  end

  describe "#count_all" do
    fab!(:post_bookmark) { Fabricate(:bookmark, user:, bookmarkable: Fabricate(:post)) }
    fab!(:topic_bookmark) { Fabricate(:bookmark, user:, bookmarkable: Fabricate(:topic)) }

    before do
      Fabricate(:topic_user, user:, topic: post_bookmark.bookmarkable.topic)
      Fabricate(:topic_user, user:, topic: topic_bookmark.bookmarkable)
    end

    it "counts all accessible bookmarks" do
      expect(bookmark_query.count_all).to eq(2)
    end

    it "excludes deleted bookmarkables" do
      post_bookmark.bookmarkable.trash!
      expect(bookmark_query.count_all).to eq(1)
    end

    it "excludes bookmarks in inaccessible private categories" do
      group = Fabricate(:group)
      post_bookmark.bookmarkable.topic.update!(category: Fabricate(:private_category, group:))
      expect(bookmark_query.count_all).to eq(1)

      group.add(user)
      expect(bookmark_query(guardian: Guardian.new(user.reload)).count_all).to eq(2)
    end

    it "returns 0 when all bookmarks are inaccessible" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      post_bookmark.bookmarkable.topic.update!(category: private_category)
      topic_bookmark.bookmarkable.update!(category: private_category)
      expect(bookmark_query.count_all).to eq(0)
    end
  end

  describe "#list_all" do
    fab!(:post_bookmark) { Fabricate(:bookmark, user:, bookmarkable: Fabricate(:post)) }
    fab!(:topic_bookmark) { Fabricate(:bookmark, user:, bookmarkable: Fabricate(:topic)) }

    let(:user_bookmark) do
      Fabricate(:bookmark, user:, bookmarkable: Fabricate(:user, username: "bookmarkqueen"))
    end

    before do
      register_test_bookmarkable
      Fabricate(:topic_user, user:, topic: post_bookmark.bookmarkable.topic)
      Fabricate(:topic_user, user:, topic: topic_bookmark.bookmarkable)
      user_bookmark
    end

    after { DiscoursePluginRegistry.reset! }

    it "returns all bookmarks for a user" do
      expect(bookmark_query.list_all.map(&:id)).to contain_exactly(
        post_bookmark.id,
        topic_bookmark.id,
        user_bookmark.id,
      )
    end

    it "excludes deleted bookmarkables" do
      post_bookmark.bookmarkable.trash!
      topic_bookmark.bookmarkable.trash!
      expect(bookmark_query.list_all.map(&:id)).to contain_exactly(user_bookmark.id)
    end

    it "runs on_preload callbacks" do
      preloaded = []
      BookmarkQuery.on_preload { |bookmarks, _| preloaded.concat(bookmarks) }
      bookmark_query.list_all
      expect(preloaded).to be_present
    end

    it "handles nil from bookmarkable list_query" do
      UserTestBookmarkable.expects(:list_query).returns(nil)
      expect(bookmark_query.list_all.map(&:id)).to contain_exactly(
        post_bookmark.id,
        topic_bookmark.id,
      )
    end

    it "returns empty when user has no accessible bookmarks" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      topic_bookmark.bookmarkable.update!(category: private_category)
      post_bookmark.bookmarkable.topic.update!(category: private_category)
      UserTestBookmarkable.expects(:list_query).returns(nil)
      expect(bookmark_query.list_all).to be_empty
    end

    context "with search_term" do
      before_all { SearchIndexer.enable }

      fab!(:named_bookmark) do
        bm = Fabricate(:bookmark, user:, name: "Check later", bookmarkable: Fabricate(:post))
        Fabricate(:topic_user, user:, topic: bm.bookmarkable.topic)
        bm
      end

      fab!(:content_bookmark) do
        post =
          Fabricate(
            :post,
            raw: "Special content here",
            topic: Fabricate(:topic, title: "Unique topic title"),
          )
        bm = Fabricate(:bookmark, user:, bookmarkable: post)
        Fabricate(:topic_user, user:, topic: post.topic)
        bm
      end

      it "searches by bookmark name" do
        expect(bookmark_query(search_term: "check").list_all.map(&:id)).to eq([named_bookmark.id])
      end

      it "searches by post content" do
        expect(bookmark_query(search_term: "special").list_all.map(&:id)).to eq(
          [content_bookmark.id],
        )
      end

      it "searches by topic title" do
        expect(bookmark_query(search_term: "unique").list_all.map(&:id)).to eq(
          [content_bookmark.id],
        )
      end

      it "handles colons in search term" do
        named_bookmark.update!(name: "Review with:images")
        expect(bookmark_query(search_term: "with:images").list_all.map(&:id)).to eq(
          [named_bookmark.id],
        )
      end
    end

    context "with whispered posts" do
      fab!(:whisperers_group, :group)

      before do
        post_bookmark.bookmarkable.update!(post_type: Post.types[:whisper])
        SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
      end

      it "includes whisper for moderator" do
        user.grant_moderation!
        expect(bookmark_query.list_all).to include(post_bookmark)
      end

      it "includes whisper for admin" do
        user.grant_admin!
        expect(bookmark_query.list_all).to include(post_bookmark)
      end

      it "includes whisper for whisperers group member" do
        SiteSetting.whispers_allowed_groups = whisperers_group.id.to_s
        whisperers_group.add(user)
        expect(bookmark_query.list_all).to include(post_bookmark)
      end

      it "excludes whisper for regular user" do
        expect(bookmark_query.list_all).not_to include(post_bookmark)
      end
    end

    context "with private message bookmarks" do
      fab!(:pm_topic, :private_message_topic)
      fab!(:pm_post) { Fabricate(:post, topic: pm_topic) }

      before do
        post_bookmark.update!(bookmarkable: pm_post)
        TopicUser.change(user.id, pm_topic.id, total_msecs_viewed: 1)
      end

      it "includes PM bookmark for allowed user" do
        TopicAllowedUser.create!(topic: pm_topic, user:)
        expect(bookmark_query.list_all).to include(post_bookmark)
      end

      it "includes PM bookmark for allowed group member" do
        group = Fabricate(:group)
        group.add(user)
        TopicAllowedGroup.create!(topic: pm_topic, group:)
        expect(bookmark_query.list_all).to include(post_bookmark)
      end

      it "excludes PM bookmark for non-allowed user" do
        expect(bookmark_query.list_all).not_to include(post_bookmark)
      end
    end

    context "with private categories" do
      fab!(:group)
      fab!(:private_category) { Fabricate(:private_category, group:) }

      before { post_bookmark.bookmarkable.topic.update!(category: private_category) }

      it "excludes bookmark in inaccessible category" do
        expect(bookmark_query.list_all).not_to include(post_bookmark)
      end

      it "includes bookmark when user gains access" do
        group.add(user)
        expect(bookmark_query.list_all).to include(post_bookmark)
      end
    end

    context "with pagination" do
      it "respects per_page" do
        expect(bookmark_query(per_page: 1).list_all.count).to eq(1)
      end
    end
  end

  describe "#list_all ordering" do
    fab!(:bookmark1) { Fabricate(:bookmark, user:, updated_at: 1.day.ago) }
    fab!(:bookmark2) { Fabricate(:bookmark, user:, updated_at: 2.days.ago) }
    fab!(:bookmark3) { Fabricate(:bookmark, user:, updated_at: 3.days.ago) }

    before do
      [bookmark1, bookmark2, bookmark3].each do |bm|
        Fabricate(:topic_user, topic: bm.bookmarkable.topic, user:)
      end
    end

    it "orders by updated_at DESC by default" do
      expect(bookmark_query.list_all.map(&:id)).to eq([bookmark1.id, bookmark2.id, bookmark3.id])
    end

    it "prioritizes reminder_at over updated_at" do
      bookmark3.update_column(:reminder_at, 1.hour.from_now)
      expect(bookmark_query.list_all.first).to eq(bookmark3)
    end

    it "prioritizes pinned bookmarks" do
      bookmark3.update_column(:pinned, true)
      expect(bookmark_query.list_all.first).to eq(bookmark3)
    end
  end

  describe "#unread_notifications" do
    fab!(:post)
    fab!(:bookmark) { Fabricate(:bookmark, user:, bookmarkable: post) }

    before { Fabricate(:topic_user, user:, topic: post.topic) }

    def create_reminder_notification(bm)
      topic =
        case bm.bookmarkable
        when Post
          bm.bookmarkable.topic
        when Topic
          bm.bookmarkable
        end

      Fabricate(
        :notification,
        user:,
        topic:,
        notification_type: Notification.types[:bookmark_reminder],
        data: {
          bookmark_id: bm.id,
          bookmarkable_type: bm.bookmarkable_type,
          bookmarkable_id: bm.bookmarkable_id,
        }.to_json,
      )
    end

    it "returns unread bookmark reminder notifications" do
      notification = create_reminder_notification(bookmark)
      expect(bookmark_query.unread_notifications).to contain_exactly(notification)
    end

    it "excludes notifications for inaccessible bookmarks" do
      create_reminder_notification(bookmark)
      post.topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))
      expect(bookmark_query.unread_notifications).to be_empty
    end

    it "handles deleted bookmarks by checking bookmarkable access" do
      notification = create_reminder_notification(bookmark)
      bookmark.delete # Use delete to skip callbacks and keep the notification

      expect(bookmark_query.unread_notifications).to contain_exactly(notification)
    end

    it "excludes notifications for deleted bookmarks with inaccessible bookmarkables" do
      create_reminder_notification(bookmark)
      bookmark.delete # Use delete to skip callbacks and keep the notification
      post.topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))
      expect(bookmark_query.unread_notifications).to be_empty
    end

    it "respects limit parameter" do
      3.times do
        bm = Fabricate(:bookmark, user:, bookmarkable: Fabricate(:post))
        Fabricate(:topic_user, user:, topic: bm.bookmarkable.topic)
        create_reminder_notification(bm)
      end

      expect(bookmark_query.unread_notifications(limit: 2).count).to eq(2)
    end
  end
end
