# frozen_string_literal: true

describe TopicLocalizationDestroyer do
  fab!(:user)
  fab!(:group)
  fab!(:topic)
  fab!(:localization) { Fabricate(:topic_localization, topic:, locale: "ja") }

  let(:locale) { "ja" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "deletes the localization" do
    expect {
      described_class.destroy(topic_id: topic.id, locale: locale, acting_user: user)
    }.to change { TopicLocalization.count }.by(-1)
    expect { TopicLocalization.find(localization.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "raises not found if the localization is missing" do
    expect {
      described_class.destroy(topic_id: topic.id, locale: "nope", acting_user: user)
    }.to raise_error(Discourse::NotFound)
  end
end
