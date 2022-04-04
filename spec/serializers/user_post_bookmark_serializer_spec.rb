# frozen_string_literal: true

RSpec.describe UserPostBookmarkSerializer do
  before do
    SiteSetting.use_polymorphic_bookmarks = true
  end

  let(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post, user: user, topic: topic) }
  let(:topic) { Fabricate(:topic) }
  let!(:bookmark) { Fabricate(:bookmark, name: 'Test', user: user, bookmarkable: post) }

  it "uses the correct highest_post_number column based on whether the user is staff" do
    Fabricate(:post, topic: topic)
    Fabricate(:post, topic: topic)
    Fabricate(:whisper, topic: topic)
    topic.reload
    bookmark.reload
    serializer = UserPostBookmarkSerializer.new(bookmark, post, scope: Guardian.new(user))

    expect(serializer.highest_post_number).to eq(3)

    user.update!(admin: true)

    expect(serializer.highest_post_number).to eq(4)
  end
end
