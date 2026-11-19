# frozen_string_literal: true

RSpec.describe UserBookmarkList do
  fab!(:user)
  let(:list) { UserBookmarkList.new(user: user, guardian: Guardian.new(user)) }

  before { register_test_bookmarkable }

  after { DiscoursePluginRegistry.reset! }

  let(:post_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:post)) }
  let(:topic_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:topic_with_op)) }
  let(:user_bookmark) { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:user)) }

  it "returns all types of bookmarks" do
    Fabricate(:topic_user, user: user, topic: post_bookmark.bookmarkable.topic)
    Fabricate(:topic_user, user: user, topic: topic_bookmark.bookmarkable)
    user_bookmark

    queries = track_sql_queries { list.load }
    expect(queries.grep(/SELECT COUNT/)).to be_empty
    expect(queries.grep(/\ASELECT "bookmarks"\.\* FROM "bookmarks"/)).to be_empty

    expect(list.bookmarks.map(&:id)).to match_array(
      [post_bookmark.id, topic_bookmark.id, user_bookmark.id],
    )

    expect(list.has_more).to eq(false)
  end

  it "defaults to 20 per page" do
    expect(list.per_page).to eq(20)
  end

  context "when the per_page param is too high" do
    it "does not allow more than X bookmarks to be requested per page" do
      topic = Fabricate(:topic, user: user)
      Fabricate(:topic_user, topic: topic, user: user)

      21.times do
        post = Fabricate(:post, topic: topic, user: user)
        Fabricate(:bookmark, user: user, bookmarkable: post)
      end

      list = UserBookmarkList.new(user: user, guardian: Guardian.new(user), per_page: 1000)

      expect(list.load.count).to eq(20)
      expect(list.has_more).to eq(true)
    end
  end
end
