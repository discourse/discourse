# frozen_string_literal: true

describe PostLocalizationDestroyer do
  fab!(:user)
  fab!(:post)
  fab!(:group)
  fab!(:localization) { Fabricate(:post_localization, post:, locale: "ja") }

  fab!(:locale) { "ja" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "deletes the localization" do
    expect {
      described_class.destroy(post_id: post.id, locale: locale, acting_user: user)
    }.to change { PostLocalization.count }.by(-1)
    expect { PostLocalization.find(localization.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "raises not found if the localization is missing" do
    expect {
      described_class.destroy(post_id: post.id, locale: "nope", acting_user: user)
    }.to raise_error(Discourse::NotFound)
  end

  it "publishes MessageBus notification" do
    messages =
      MessageBus.track_publish("/topic/#{post.topic_id}") do
        described_class.destroy(post_id: post.id, locale: locale, acting_user: user)
      end

    expect(messages.length).to eq(1)
    expect(messages.first.data[:type]).to eq(:revised)
    expect(messages.first.data[:id]).to eq(post.id)
  end

  context "with author localization" do
    fab!(:author, :user)
    fab!(:author_post) { Fabricate(:post, user: author) }
    fab!(:other_post, :post)
    fab!(:post_localization) { Fabricate(:post_localization, post: author_post, locale:) }

    before { SiteSetting.content_localization_allow_author_localization = true }

    it "allows post author to create localization for their own post" do
      localization = described_class.destroy(post_id: author_post.id, locale:, acting_user: author)

      expect(localization).to be_nil
    end

    it "raises permission error if user is not the post author" do
      expect {
        described_class.destroy(post_id: other_post.id, locale:, acting_user: author)
      }.to raise_error(Discourse::InvalidAccess)
    end
  end
end
