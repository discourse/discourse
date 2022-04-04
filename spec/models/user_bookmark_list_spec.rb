# frozen_string_literal: true

RSpec.describe UserBookmarkList do
  let(:params) { {} }
  fab!(:user) { Fabricate(:user) }
  let(:list) { UserBookmarkList.new(user: user, guardian: Guardian.new(user), params: params) }

  context "for non-polymorphic bookmarks" do
    before do
      22.times do
        bookmark = Fabricate(:bookmark, user: user)
        Fabricate(:topic_user, topic: bookmark.topic, user: user)
      end
    end

    it "defaults to 20 per page" do
      expect(list.per_page).to eq(20)
    end

    context "when the per_page param is too high" do
      let(:params) { { per_page: 1000 } }

      it "does not allow more than X bookmarks to be requested per page" do
        expect(list.load.count).to eq(20)
      end
    end
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
    let(:user_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:user)) }

    it "returns all types of bookmarks" do
      list.load
      expect(list.bookmarks.map(&:id)).to match_array([post_bookmark.id, topic_bookmark.id, user_bookmark.id])
    end

    it "registeres an attr_reader and fills it with the preloaded association" do
      list.load
      expect(list.users).to eq([user_bookmark.bookmarkable])
    end
  end
end
