# frozen_string_literal: true

RSpec.describe BookmarkQuery do
  before do
    SearchIndexer.enable
  end

  fab!(:user) { Fabricate(:user) }
  let(:params) { {} }

  def bookmark_query(user: nil, params: nil)
    BookmarkQuery.new(user: user || self.user, params: params || self.params)
  end

  describe "#list_all" do
    fab!(:bookmark1) { Fabricate(:bookmark, user: user) }
    fab!(:bookmark2) { Fabricate(:bookmark, user: user) }
    let!(:topic_user1) { Fabricate(:topic_user, topic: bookmark1.topic, user: user) }
    let!(:topic_user2) { Fabricate(:topic_user, topic: bookmark2.topic, user: user) }

    it "returns all the bookmarks for a user" do
      expect(bookmark_query.list_all.count).to eq(2)
    end

    it "does not return deleted posts" do
      bookmark1.post.trash!
      expect(bookmark_query.list_all.count).to eq(1)
    end

    it "does not return deleted topics" do
      bookmark1.topic.trash!
      expect(bookmark_query.list_all.count).to eq(1)
    end

    it "runs the on_preload block provided passing in bookmarks" do
      preloaded_bookmarks = []
      BookmarkQuery.on_preload do |bookmarks, bq|
        (preloaded_bookmarks << bookmarks).flatten
      end
      bookmark_query.list_all
      expect(preloaded_bookmarks.any?).to eq(true)
    end

    it "does not query topic_users for the bookmark topic that are not the current user" do
      topic_user3 = Fabricate(:topic_user, topic: bookmark1.topic)
      bookmark = bookmark_query.list_all.find do |b|
        b.topic_id == bookmark1.topic_id
      end

      expect(bookmark.topic.topic_users.map(&:user_id)).to contain_exactly(user.id)
    end

    context "for polymorphic bookmarks" do
      before do
        SiteSetting.use_polymorphic_bookmarks = true
        Bookmark.register_bookmarkable(
          model: User,
          serializer: UserBookmarkSerializer,
          search_fields: ["username"]
        )

        Fabricate(:topic_user, user: user, topic: post_bookmark.bookmarkable.topic)
        Fabricate(:topic_user, user: user, topic: topic_bookmark.bookmarkable)
        user_bookmark
      end

      let(:post_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:post)) }
      let(:topic_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:topic)) }
      let(:user_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:user, username: "bookmarkqueen")) }

      after do
        Bookmark.registered_bookmarkables = []
      end

      it "returns a mixture of post, topic, and custom bookmarkable type bookmarks" do
        bookmarks = bookmark_query.list_all
        expect(bookmarks.map(&:id)).to match_array([post_bookmark.id, topic_bookmark.id, user_bookmark.id])
      end
    end

    context "when q param is provided" do
      let!(:post) { Fabricate(:post, raw: "Some post content here", topic: Fabricate(:topic, title: "Bugfix game for devs")) }

      context "when not using polymorphic bookmarks" do
        let(:bookmark3) { Fabricate(:bookmark, user: user, name: "Check up later") }
        let(:bookmark4) { Fabricate(:bookmark, user: user, post: post) }

        before do
          Fabricate(:topic_user, user: user, topic: bookmark3.topic)
          Fabricate(:topic_user, user: user, topic: bookmark4.topic)
        end

        it "can search by bookmark name" do
          bookmarks = bookmark_query(params: { q: 'check' }).list_all
          expect(bookmarks.map(&:id)).to eq([bookmark3.id])
        end

        it "can search by post content" do
          bookmarks = bookmark_query(params: { q: 'content' }).list_all
          expect(bookmarks.map(&:id)).to eq([bookmark4.id])
        end

        it "can search by topic title" do
          bookmarks = bookmark_query(params: { q: 'bugfix' }).list_all
          expect(bookmarks.map(&:id)).to eq([bookmark4.id])
        end
      end

      context "when using polymorphic bookmarks" do
        before do
          SiteSetting.use_polymorphic_bookmarks = true
        end

        let(:bookmark3) { Fabricate(:bookmark, user: user, name: "Check up later", bookmarkable: Fabricate(:post)) }
        let(:bookmark4) { Fabricate(:bookmark, user: user, bookmarkable: post) }

        before do
          Fabricate(:topic_user, user: user, topic: bookmark3.bookmarkable.topic)
          Fabricate(:topic_user, user: user, topic: bookmark4.bookmarkable.topic)
        end

        it "can search by bookmark name" do
          bookmarks = bookmark_query(params: { q: 'check' }).list_all
          expect(bookmarks.map(&:id)).to eq([bookmark3.id])
        end

        it "can search by post content" do
          bookmarks = bookmark_query(params: { q: 'content' }).list_all
          expect(bookmarks.map(&:id)).to eq([bookmark4.id])
        end

        it "can search by topic title" do
          bookmarks = bookmark_query(params: { q: 'bugfix' }).list_all
          expect(bookmarks.map(&:id)).to eq([bookmark4.id])
        end

        context "with custom bookmarkable fitering" do
          before do
            Bookmark.register_bookmarkable(
              model: User,
              serializer: UserBookmarkSerializer,
              search_fields: ["username"]
            )
          end

          let!(:bookmark5) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:user, username: "bookmarkqueen")) }

          after do
            Bookmark.registered_bookmarkables = []
          end

          it "allows searching bookmarkables by fields in other tables" do
            bookmarks = bookmark_query(params: { q: 'bookmarkq' }).list_all
            expect(bookmarks.map(&:id)).to eq([bookmark5.id])
          end
        end
      end
    end

    context "for a whispered post" do
      before do
        bookmark1.post.update(post_type: Post.types[:whisper])
      end
      context "when the user is moderator" do
        it "does return the whispered post" do
          user.update!(moderator: true)
          expect(bookmark_query.list_all.count).to eq(2)
        end
      end
      context "when the user is admin" do
        it "does return the whispered post" do
          user.update!(admin: true)
          expect(bookmark_query.list_all.count).to eq(2)
        end
      end
      context "when the user is not staff" do
        it "does not return the whispered post" do
          expect(bookmark_query.list_all.count).to eq(1)
        end
      end
    end

    context "for a private message topic bookmark" do
      let(:pm_topic) { Fabricate(:private_message_topic) }
      before do
        bookmark1.update(post: Fabricate(:post, topic: pm_topic))
        TopicUser.change(user.id, pm_topic.id, total_msecs_viewed: 1)
      end

      context "when the user is a topic_allowed_user" do
        before do
          TopicAllowedUser.create(topic: pm_topic, user: user)
        end
        it "shows the user the bookmark in the PM" do
          expect(bookmark_query.list_all.map(&:id).count).to eq(2)
        end
      end

      context "when the user is in a topic_allowed_group" do
        before do
          group = Fabricate(:group)
          GroupUser.create(group: group, user: user)
          TopicAllowedGroup.create(topic: pm_topic, group: group)
        end
        it "shows the user the bookmark in the PM" do
          expect(bookmark_query.list_all.map(&:id).count).to eq(2)
        end
      end

      context "when the user is not a topic_allowed_user" do
        it "does not show the user a bookmarked post in a PM where they are not an allowed user" do
          expect(bookmark_query.list_all.map(&:id).count).to eq(1)
        end
      end

      context "when the user is not in a topic_allowed_group" do
        it "does not show the user a bookmarked post in a PM where they are not in an allowed group" do
          expect(bookmark_query.list_all.map(&:id).count).to eq(1)
        end
      end
    end

    context "when the topic category is private" do
      let(:group) { Fabricate(:group) }
      before do
        bookmark1.topic.update(category: Fabricate(:private_category, group: group))
        bookmark1.reload
      end
      it "does not show the user a post/topic in a private category they cannot see" do
        expect(bookmark_query.list_all.map(&:id)).not_to include(bookmark1.id)
      end
      it "does show the user a post/topic in a private category they can see" do
        GroupUser.create(user: user, group: group)
        expect(bookmark_query.list_all.map(&:id)).to include(bookmark1.id)
      end
    end

    context "when the limit param is provided" do
      let(:params) { { limit: 1 } }
      it "is respected" do
        expect(bookmark_query.list_all.count).to eq(1)
      end
    end
  end

  describe "#list_all ordering" do
    let!(:bookmark1) { Fabricate(:bookmark, user: user, updated_at: 1.day.ago, reminder_at: nil) }
    let!(:bookmark2) { Fabricate(:bookmark, user: user, updated_at: 2.days.ago, reminder_at: nil) }
    let!(:bookmark3) { Fabricate(:bookmark, user: user, updated_at: 6.days.ago, reminder_at: nil) }
    let!(:bookmark4) { Fabricate(:bookmark, user: user, updated_at: 4.days.ago, reminder_at: nil) }
    let!(:bookmark5) { Fabricate(:bookmark, user: user, updated_at: 3.days.ago, reminder_at: nil) }

    before do
      [bookmark1, bookmark2, bookmark3, bookmark4, bookmark5].each do |bm|
        Fabricate(:topic_user, topic: bm.topic, user: user)
        bm.reload
      end
    end

    it "order defaults to updated_at DESC" do
      expect(bookmark_query.list_all.map(&:id)).to eq([
        bookmark1.id,
        bookmark2.id,
        bookmark5.id,
        bookmark4.id,
        bookmark3.id
      ])
    end

    it "orders by reminder_at, then updated_at" do
      bookmark4.update_column(:reminder_at, 1.day.from_now)
      bookmark5.update_column(:reminder_at, 26.hours.from_now)

      expect(bookmark_query.list_all.map(&:id)).to eq([
        bookmark4.id,
        bookmark5.id,
        bookmark1.id,
        bookmark2.id,
        bookmark3.id
      ])
    end

    it "shows pinned bookmarks first ordered by reminder_at ASC then updated_at DESC" do
      bookmark3.update_column(:pinned, true)
      bookmark3.update_column(:reminder_at, 1.day.from_now)

      bookmark4.update_column(:pinned, true)
      bookmark4.update_column(:reminder_at, 28.hours.from_now)

      bookmark1.update_column(:pinned, true)
      bookmark2.update_column(:pinned, true)

      bookmark5.update_column(:reminder_at, 1.day.from_now)

      expect(bookmark_query.list_all.map(&:id)).to eq([
        bookmark3.id,
        bookmark4.id,
        bookmark1.id,
        bookmark2.id,
        bookmark5.id
      ])
    end
  end
end
