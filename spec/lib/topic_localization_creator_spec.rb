# frozen_string_literal: true

describe TopicLocalizationCreator do
  fab!(:user)
  fab!(:topic)
  fab!(:group)

  let(:locale) { "ja" }
  let(:title) { "これは翻訳です" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "creates a topic localization record" do
    localization = described_class.create(topic:, locale:, title:, user:)

    expect(TopicLocalization.find(localization.id)).to have_attributes(
      topic_id: topic.id,
      locale:,
      title:,
      localizer_user_id: user.id,
      fancy_title: Topic.fancy_title(title),
    )
  end

  it "raises permission error if user not in allowed groups" do
    group.remove(user)
    expect { described_class.create(topic:, locale:, title:, user:) }.to raise_error(
      Discourse::InvalidAccess,
    )
  end

  context "with author localization" do
    fab!(:author, :user)
    fab!(:author_topic) { Fabricate(:topic, user: author) }
    fab!(:other_topic, :topic)

    before do
      SiteSetting.content_localization_allow_author_localization = true
      group.remove(author)
    end

    it "allows topic author to create localization for their own topic" do
      localization = described_class.create(topic: author_topic, locale:, title:, user: author)

      expect(localization).to have_attributes(
        topic_id: author_topic.id,
        locale:,
        title:,
        localizer_user_id: author.id,
      )
    end

    it "raises permission error if user is not the topic author" do
      expect {
        described_class.create(topic: other_topic, locale:, title:, user: author)
      }.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe "excerpt from existing post localization" do
    fab!(:first_post) { Fabricate(:post, topic: topic, post_number: 1) }

    it "sets excerpt from existing post localization" do
      Fabricate(
        :post_localization,
        post: first_post,
        locale: locale,
        raw: "これは投稿の内容です。",
        cooked: "<p>これは投稿の内容です。</p>",
      )

      localization = described_class.create(topic:, locale:, title:, user:)

      expect(localization.excerpt).to eq("これは投稿の内容です。")
    end

    it "sets excerpt to nil when no post localization exists" do
      localization = described_class.create(topic:, locale:, title:, user:)

      expect(localization.excerpt).to be_nil
    end

    it "sets excerpt to nil when post localization exists for different locale" do
      Fabricate(
        :post_localization,
        post: first_post,
        locale: "fr",
        raw: "Ceci est le contenu du post.",
        cooked: "<p>Ceci est le contenu du post.</p>",
      )

      localization = described_class.create(topic:, locale:, title:, user:)

      expect(localization.excerpt).to be_nil
    end
  end
end
