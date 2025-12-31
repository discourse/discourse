# frozen_string_literal: true

RSpec.describe Jobs::SyncTopicUserBookmarked do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  fab!(:tu1) { Fabricate(:topic_user, topic:, bookmarked: false) }
  fab!(:tu2) { Fabricate(:topic_user, topic:, bookmarked: false) }
  fab!(:tu3) { Fabricate(:topic_user, topic:, bookmarked: true) }
  fab!(:tu4) { Fabricate(:topic_user, topic:, bookmarked: true) }

  def execute
    described_class.new.execute(topic_id: topic.id)
  end

  it "syncs bookmarked to true for users with Post bookmarks and false for those without" do
    Fabricate(:bookmark, user: tu1.user, bookmarkable: post)

    execute

    expect(tu1.reload.bookmarked).to eq(true)
    expect(tu2.reload.bookmarked).to eq(false)
    expect(tu3.reload.bookmarked).to eq(false)
    expect(tu4.reload.bookmarked).to eq(false)
  end

  it "syncs bookmarked to true for users with Topic bookmarks" do
    Fabricate(:bookmark, user: tu1.user, bookmarkable: topic)

    execute

    expect(tu1.reload.bookmarked).to eq(true)
  end

  it "syncs bookmarked to false when bookmarked post is deleted" do
    Fabricate(:bookmark, user: tu1.user, bookmarkable: post)
    post.trash!

    execute

    expect(tu1.reload.bookmarked).to eq(false)
  end

  it "handles Topic and Post bookmarks from different users correctly" do
    Fabricate(:bookmark, user: tu3.user, bookmarkable: topic)
    Fabricate(:bookmark, user: tu4.user, bookmarkable: post)

    execute

    expect(tu3.reload.bookmarked).to eq(true)
    expect(tu4.reload.bookmarked).to eq(true)
  end
end
