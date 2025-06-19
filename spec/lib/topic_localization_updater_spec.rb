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
    localization =
      described_class.update(topic_id: topic.id, locale: locale, title: new_title, user: user)

    expect(localization).to have_attributes(
      title: new_title,
      fancy_title: Topic.fancy_title(new_title),
      localizer_user_id: user.id,
    )
  end

  it "raises not found if the localization is missing" do
    expect {
      described_class.update(topic_id: topic.id, locale: "nope", title: new_title, user: user)
    }.to raise_error(Discourse::NotFound)
  end

  it "raises not found if the topic is missing" do
    expect {
      described_class.update(topic_id: -1, locale: locale, title: new_title, user: user)
    }.to raise_error(Discourse::NotFound)
  end
end
