# frozen_string_literal: true

RSpec.describe UserBookmarkList do
  let(:params) { {} }
  fab!(:user) { Fabricate(:user) }
  let(:list) { UserBookmarkList.new(user: user, guardian: Guardian.new(user), params: params) }

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

  it "returns all types of bookmarks" do
    list.load
    expect(list.bookmarks.map(&:id)).to match_array(
      [post_bookmark.id, topic_bookmark.id, user_bookmark.id],
    )
    expect(list.has_more).to eq(false)
  end

  it "defaults to 20 per page" do
    expect(list.per_page).to eq(20)
  end

  context "when the per_page param is too high" do
    let(:params) { { per_page: 1000 } }

    it "does not allow more than X bookmarks to be requested per page" do
      22.times do
        bookmark = Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:post))
        Fabricate(:topic_user, topic: bookmark.bookmarkable.topic, user: user)
      end
      expect(list.load.count).to eq(20)
    end
  end
end
