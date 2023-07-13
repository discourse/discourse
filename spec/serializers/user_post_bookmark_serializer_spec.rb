# frozen_string_literal: true

RSpec.describe UserPostBookmarkSerializer do
  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic) }
  let(:post) { Fabricate(:post, user: user, topic: topic) }
  let!(:bookmark) { Fabricate(:bookmark, name: "Test", user: user, bookmarkable: post) }

  describe "#highest_post_number" do
    let(:whisperers_group) { Fabricate(:group) }

    before { SiteSetting.whispers_allowed_groups = "#{whisperers_group.id}" }

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
end
