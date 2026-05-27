# frozen_string_literal: true

describe TopicLocalizationUpdater do
  fab!(:user)
  fab!(:topic)
  fab!(:group)
  fab!(:topic_localization) do
    Fabricate(:topic_localization, topic:, locale: "ja", title: "古いバージョン")
  end

  let(:locale) { "ja" }
  let(:new_title) { "新しいバージョンです" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "updates an existing localization" do
    localization = described_class.update(topic:, locale:, title: new_title, user:)

    expect(localization).to have_attributes(
      title: new_title,
      fancy_title: Topic.fancy_title(new_title),
      localizer_user_id: user.id,
    )
  end

  it "returns the localization unchanged if the title is the same" do
    localization = described_class.update(topic:, locale:, title: topic_localization.title, user:)

    expect(localization.id).to eq(topic_localization.id)
    expect(localization.localizer_user_id).not_to eq(user.id)
  end

  it "raises not found if the localization is missing" do
    expect {
      described_class.update(topic:, locale: "nope", title: new_title, user:)
    }.to raise_error(Discourse::NotFound)
  end

  it "raises permission error if user not in allowed groups" do
    group.remove(user)
    expect { described_class.update(topic:, locale:, title: new_title, user:) }.to raise_error(
      Discourse::InvalidAccess,
    )
  end

  context "with author localization" do
    fab!(:author, :user)
    fab!(:author_topic) { Fabricate(:topic, user: author) }
    fab!(:author_topic_localization) do
      Fabricate(:topic_localization, topic: author_topic, locale: "ja", title: "古いバージョン")
    end

    before do
      SiteSetting.content_localization_allow_author_localization = true
      group.remove(author)
    end

    it "allows topic author to update localization for their own topic" do
      localization =
        described_class.update(topic: author_topic, locale: "ja", title: new_title, user: author)

      expect(localization).to have_attributes(
        title: new_title,
        fancy_title: Topic.fancy_title(new_title),
        localizer_user_id: author.id,
      )
    end

    it "raises permission error if user is not the topic author" do
      expect {
        described_class.update(topic:, locale:, title: new_title, user: author)
      }.to raise_error(Discourse::InvalidAccess)
    end
  end
end
