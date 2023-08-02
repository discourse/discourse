# frozen_string_literal: true

RSpec.describe UserBookmarkListSerializer do
  fab!(:user) { Fabricate(:user) }

  context "for polymorphic bookmarks" do
    before do
      register_test_bookmarkable
      Fabricate(:topic_user, user: user, topic: post_bookmark.bookmarkable.topic)
      Fabricate(:topic_user, user: user, topic: topic_bookmark.bookmarkable)
      user_bookmark
    end

    after { DiscoursePluginRegistry.reset! }

    let(:post_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:post)) }
    let(:topic_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:topic)) }
    let(:user_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:user)) }

    def run_serializer
      bookmark_list = UserBookmarkList.new(user: user, guardian: Guardian.new(user))
      bookmark_list.load
      UserBookmarkListSerializer.new(bookmark_list)
    end

    it "chooses the correct class of serializer for all the bookmarkable types" do
      serializer = run_serializer
      expect(serializer.bookmarks.map(&:class).map(&:to_s)).to match_array(
        %w[UserTestBookmarkSerializer UserTopicBookmarkSerializer UserPostBookmarkSerializer],
      )
    end
  end
end
