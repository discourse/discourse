# frozen_string_literal: true

RSpec.describe UserBookmarkListSerializer do
  class UserTestBookmarkSerializer < UserBookmarkBaseSerializer; end

  fab!(:user) { Fabricate(:user) }

  context "for polymorphic bookmarks" do
    before do
      SiteSetting.use_polymorphic_bookmarks = true
      Bookmark.register_bookmarkable(
        model: User,
        serializer: UserTestBookmarkSerializer,
        list_query: lambda do |user, guardian|
          user.bookmarks.joins(
            "INNER JOIN users ON users.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'User'"
          ).where(bookmarkable_type: "User")
        end,
        search_query: lambda do |bookmarks, query, ts_query|
          bookmarks.where("users.username ILIKE ?", query)
        end
      )

      Fabricate(:topic_user, user: user, topic: post_bookmark.bookmarkable.topic)
      Fabricate(:topic_user, user: user, topic: topic_bookmark.bookmarkable)
      user_bookmark
    end

    let(:post_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:post)) }
    let(:topic_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:topic)) }
    let(:user_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:user)) }

    def run_serializer
      bookmark_list = UserBookmarkList.new(user: user, guardian: Guardian.new(user), params: {})
      bookmark_list.load
      UserBookmarkListSerializer.new(bookmark_list)
    end

    it "chooses the correct class of serializer for all the bookmarkable types" do
      serializer = run_serializer
      expect(serializer.bookmarks.map(&:class).map(&:to_s)).to match_array(["UserTestBookmarkSerializer", "UserTopicBookmarkSerializer", "UserPostBookmarkSerializer"])
    end
  end
end
