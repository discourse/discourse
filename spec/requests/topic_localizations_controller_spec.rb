# frozen_string_literal: true

describe TopicLocalizationsController do
  fab!(:user)
  fab!(:group)
  fab!(:topic)

  let(:locale) { "ja" }
  let(:title) { "これはトピックの翻訳です。" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
    sign_in(user)
  end

  describe "#create_or_update" do
    context "when localization does not exist" do
      it "creates a new localization" do
        expect {
          post "/topic_localizations/create_or_update.json",
               params: {
                 topic_id: topic.id,
                 locale:,
                 title:,
               }
        }.to change { TopicLocalization.count }.by(1)
        expect(response.status).to eq(201)
        expect(TopicLocalization.last).to have_attributes(
          locale:,
          title:,
          topic_id: topic.id,
          localizer_user_id: user.id,
        )
      end
    end

    context "when localization already exists" do
      it "updates the existing localization" do
        topic_localization =
          Fabricate(:topic_localization, topic: topic, locale: locale, title: "Old title")
        new_user = Fabricate(:user, groups: [group])
        sign_in(new_user)

        expect {
          post "/topic_localizations/create_or_update.json",
               params: {
                 topic_id: topic.id,
                 locale: locale,
                 title: title,
               }
        }.not_to change { TopicLocalization.count }

        expect(response.status).to eq(200)
        topic_localization.reload
        expect(topic_localization).to have_attributes(
          locale: locale,
          title: title,
          localizer_user_id: new_user.id,
        )
      end
    end

    it "returns forbidden if user not in allowed group" do
      group.remove(user)
      expect {
        post "/topic_localizations/create_or_update.json",
             params: {
               topic_id: topic.id,
               locale:,
               title:,
             }
      }.not_to change { TopicLocalization.count }
      expect(response.status).to eq(403)
    end
  end

  describe "#destroy" do
    fab!(:topic_localization) { Fabricate(:topic_localization, topic:, locale: "ja") }

    it "destroys the localization" do
      expect {
        delete "/topic_localizations/destroy.json", params: { topic_id: topic.id, locale: "ja" }
      }.to change { TopicLocalization.count }.by(-1)
      expect(response.status).to eq(204)
    end

    it "returns forbidden if user not allowed" do
      group.remove(user)
      expect {
        delete "/topic_localizations/destroy.json", params: { topic_id: topic.id, locale: "ja" }
      }.not_to change { TopicLocalization.count }
      expect(response.status).to eq(403)
    end

    it "returns not found if localization is missing" do
      expect {
        delete "/topic_localizations/destroy.json", params: { topic_id: -1, locale: "ja" }
      }.not_to change { TopicLocalization.count }
      expect(response.status).to eq(404)
    end
  end

  context "with author localization" do
    fab!(:author, :user)
    fab!(:author_topic) { Fabricate(:topic, user: author) }
    fab!(:other_user, :user)

    before { group.remove(author) }

    describe "#create_or_update for topic authors" do
      it "allows topic author to create localization on their own topic" do
        sign_in(author)

        SiteSetting.content_localization_allow_author_localization = false
        expect {
          post "/topic_localizations/create_or_update.json",
               params: {
                 topic_id: author_topic.id,
                 locale:,
                 title:,
               }
        }.not_to change { TopicLocalization.count }

        SiteSetting.content_localization_allow_author_localization = true
        expect {
          post "/topic_localizations/create_or_update.json",
               params: {
                 topic_id: author_topic.id,
                 locale:,
                 title:,
               }
        }.to change { TopicLocalization.count }.by(1)
        expect(response.status).to eq(201)
        localization = TopicLocalization.last
        expect(localization.localizer_user_id).to eq(author.id)
      end

      it "denies topic author from creating localization on others' topics" do
        SiteSetting.content_localization_allow_author_localization = true
        sign_in(author)

        expect {
          post "/topic_localizations/create_or_update.json",
               params: {
                 topic_id: topic.id,
                 locale:,
                 title:,
               }
        }.not_to change { TopicLocalization.count }
        expect(response.status).to eq(403)
      end
    end

    describe "#create_or_update updates for topic authors" do
      it "allows topic author to update localization on their own topic" do
        Fabricate(:topic_localization, topic: author_topic, locale:, title: "Old title")
        SiteSetting.content_localization_allow_author_localization = true
        sign_in(author)

        expect {
          post "/topic_localizations/create_or_update.json",
               params: {
                 topic_id: author_topic.id,
                 locale:,
                 title:,
               }
        }.not_to change { TopicLocalization.count }
        expect(response.status).to eq(200)
        localization = TopicLocalization.find_by(topic: author_topic, locale:)
        expect(localization.title).to eq(title)
        expect(localization.localizer_user_id).to eq(author.id)
      end

      it "denies topic author from updating localization on others' topics" do
        Fabricate(:topic_localization, topic: topic, locale:, title: "Old title")
        SiteSetting.content_localization_allow_author_localization = true
        sign_in(author)

        expect {
          post "/topic_localizations/create_or_update.json",
               params: {
                 topic_id: topic.id,
                 locale:,
                 title:,
               }
        }.not_to change { TopicLocalization.count }
        expect(response.status).to eq(403)
      end
    end

    describe "#destroy for topic authors" do
      it "allows topic author to destroy localization on their own topic" do
        Fabricate(:topic_localization, topic: author_topic, locale:, title: "Title")
        SiteSetting.content_localization_allow_author_localization = true
        sign_in(author)

        expect {
          delete "/topic_localizations/destroy.json", params: { topic_id: author_topic.id, locale: }
        }.to change { TopicLocalization.count }.by(-1)
        expect(response.status).to eq(204)
      end

      it "denies topic author from destroying localization on others' topics" do
        Fabricate(:topic_localization, topic: topic, locale:, title: "Title")
        SiteSetting.content_localization_allow_author_localization = true
        sign_in(author)

        expect {
          delete "/topic_localizations/destroy.json", params: { topic_id: topic.id, locale: }
        }.not_to change { TopicLocalization.count }
        expect(response.status).to eq(403)
      end
    end
  end
end
