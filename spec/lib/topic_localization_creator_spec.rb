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
    localization = described_class.create(topic_id: topic.id, locale:, title:, user:)

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
    expect { described_class.create(topic_id: topic.id, locale:, title:, user:) }.to raise_error(
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
      localization =
        described_class.create(topic_id: author_topic.id, locale:, title:, user: author)

      expect(localization).to have_attributes(
        topic_id: author_topic.id,
        locale:,
        title:,
        localizer_user_id: author.id,
      )
    end

    it "raises permission error if user is not the topic author" do
      expect {
        described_class.create(topic_id: other_topic.id, locale:, title:, user: author)
      }.to raise_error(Discourse::InvalidAccess)
    end
  end
end
