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

  it "raises permission error if user not in allowed groups" do
    group.remove(user)
    expect {
      described_class.destroy(topic_id: topic.id, locale: locale, acting_user: user)
    }.to raise_error(Discourse::InvalidAccess)
  end

  context "with author localization" do
    fab!(:author, :user)
    fab!(:author_topic) { Fabricate(:topic, user: author) }
    fab!(:author_localization) { Fabricate(:topic_localization, topic: author_topic, locale: "ja") }

    before do
      SiteSetting.content_localization_allow_author_localization = true
      group.remove(author)
    end

    it "allows topic author to destroy localization for their own topic" do
      expect {
        described_class.destroy(topic_id: author_topic.id, locale: "ja", acting_user: author)
      }.to change { TopicLocalization.count }.by(-1)
      expect { TopicLocalization.find(author_localization.id) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises permission error if user is not the topic author" do
      expect {
        described_class.destroy(topic_id: topic.id, locale: locale, acting_user: author)
      }.to raise_error(Discourse::InvalidAccess)
    end
  end
end
