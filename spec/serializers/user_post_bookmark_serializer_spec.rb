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

  describe "#excerpt" do
    let(:viewer) { Fabricate(:user, locale: "ja") }

    before do
      SiteSetting.content_localization_enabled = true
      post.update!(raw: "Original post body", locale: "en")
      Fabricate(:post_localization, post: post, locale: "ja", cooked: "<p>翻訳された本文</p>")
    end

    it "returns the translated excerpt" do
      I18n.with_locale(:ja) do
        serializer = UserPostBookmarkSerializer.new(bookmark, scope: Guardian.new(viewer))

        expect(serializer.excerpt).to eq("翻訳された本文")
      end
    end
  end
end
