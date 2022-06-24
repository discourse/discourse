# frozen_string_literal: true

RSpec.describe UserPostBookmarkSerializer do
  let(:whisperers_group) { Fabricate(:group) }
  let(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post, user: user, topic: topic) }
  let(:topic) { Fabricate(:topic) }
  let!(:bookmark) { Fabricate(:bookmark, name: 'Test', user: user, bookmarkable: post) }

  before do
    SiteSetting.enable_whispers = true
    SiteSetting.whispers_allowed_groups = "#{whisperers_group.id}"
  end

  it "uses the correct highest_post_number column based on whether the user is whisperer" do
    Fabricate(:post, topic: topic)
    Fabricate(:post, topic: topic)
    Fabricate(:whisper, topic: topic)
    topic.reload
    bookmark.reload
    serializer = UserPostBookmarkSerializer.new(bookmark, scope: Guardian.new(user))

    expect(serializer.highest_post_number).to eq(3)

    user.groups << whisperers_group

    expect(serializer.highest_post_number).to eq(4)
  end
end
