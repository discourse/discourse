# frozen_string_literal: true

describe TopicLocalizationsController do
  fab!(:user)
  fab!(:group)
  fab!(:topic)

  let(:locale) { "ja" }
  let(:title) { "これはトピックの翻訳です。" }

  before do
    SiteSetting.experimental_content_localization = true
    SiteSetting.experimental_content_localization_allowed_groups = group.id.to_s
    group.add(user)
    sign_in(user)
  end

  describe "#create" do
    it "creates a new localization" do
      expect {
        post "/topic_localizations.json", params: { topic_id: topic.id, locale:, title: }
      }.to change { TopicLocalization.count }.by(1)
      expect(response.status).to eq(201)
      expect(TopicLocalization.last).to have_attributes(
        locale:,
        title:,
        topic_id: topic.id,
        localizer_user_id: user.id,
      )
    end

    it "returns forbidden if user not in allowed group" do
      group.remove(user)
      expect {
        post "/topic_localizations.json", params: { topic_id: topic.id, locale:, title: }
      }.not_to change { TopicLocalization.count }
      expect(response.status).to eq(403)
    end

    it "returns not found if topic does not exist" do
      post "/topic_localizations.json", params: { topic_id: -1, locale:, title: }
      expect(response.status).to eq(404)
    end
  end

  describe "#update" do
    fab!(:topic_localization) { Fabricate(:topic_localization, topic:, locale: "ja") }

    it "updates an existing localization" do
      new_user = Fabricate(:user, groups: [group])
      sign_in(new_user)

      put "/topic_localizations/#{topic_localization.id}.json",
          params: {
            topic_id: topic.id,
            locale:,
            title:,
          }
      expect(response.status).to eq(200)
      topic_localization.reload
      expect(topic_localization).to have_attributes(locale:, title:, localizer_user_id: new_user.id)
    end

    it "returns forbidden if user not in allowed group" do
      group.remove(user)
      expect {
        put "/topic_localizations/#{topic_localization.id}.json",
            params: {
              topic_id: topic.id,
              locale:,
              title:,
            }
      }.not_to change { topic_localization }
      expect(response.status).to eq(403)
    end

    it "returns not found if localization is missing" do
      put "/topic_localizations.json", params: { topic_id: topic.id, locale: "de", title: "何か" }
      expect(response.status).to eq(404)
    end
  end

  describe "#destroy" do
    fab!(:topic_localization) { Fabricate(:topic_localization, topic:, locale: "ja") }

    it "destroys the localization" do
      expect {
        delete "/topic_localizations/#{topic_localization.id}.json",
               params: {
                 topic_id: topic.id,
                 locale:,
               }
      }.to change { TopicLocalization.count }.by(-1)
      expect(response.status).to eq(204)
    end

    it "returns forbidden if user not allowed" do
      group.remove(user)
      expect {
        delete "/topic_localizations/#{topic_localization.id}.json",
               params: {
                 topic_id: topic.id,
                 locale:,
               }
      }.not_to change { TopicLocalization.count }
      expect(response.status).to eq(403)
    end

    it "returns not found if localization is missing" do
      expect {
        delete "/topic_localizations/219873918.json", params: { topic_id: 219_873_918, locale: }
      }.not_to change { TopicLocalization.count }
      expect(response.status).to eq(404)
    end
  end
end
