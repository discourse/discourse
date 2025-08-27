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

  it "raises not found if the topic is missing" do
    expect { described_class.create(topic_id: -1, locale:, title:, user:) }.to raise_error(
      Discourse::NotFound,
    )
  end
end
