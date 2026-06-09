# frozen_string_literal: true

RSpec.describe ReviewableFlaggedPostSerializer do
  fab!(:admin)

  it "includes the user fields for review" do
    p0 = Fabricate(:post)
    reviewable = PostActionCreator.spam(Fabricate(:user, refresh_auto_groups: true), p0).reviewable
    json =
      ReviewableFlaggedPostSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
    expect(json[:cooked]).to eq(p0.cooked)
    expect(json[:raw]).to eq(p0.raw)
    expect(json[:target_url]).to eq(Discourse.base_url + p0.url)
    expect(json[:created_from_flag]).to eq(true)
  end

  it "includes the localized cooked post when content localization is enabled" do
    SiteSetting.content_localization_enabled = true
    post = Fabricate(:post, raw: "Original post", locale: "en")
    Fabricate(:post_localization, post: post, cooked: "<p>翻訳された投稿</p>", locale: "ja")
    reviewable =
      PostActionCreator.spam(Fabricate(:user, refresh_auto_groups: true), post).reviewable

    I18n.with_locale(:ja) do
      json =
        ReviewableFlaggedPostSerializer.new(
          reviewable,
          scope: Guardian.new(admin),
          root: nil,
        ).as_json

      expect(json[:cooked]).to eq("<p>翻訳された投稿</p>")
    end
  end

  it "works when the topic is deleted" do
    reviewable = Fabricate(:reviewable_queued_post)
    reviewable.topic.update(deleted_at: Time.now)
    reviewable.reload

    json =
      ReviewableQueuedPostSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
    expect(json[:id]).to be_present
  end
end
