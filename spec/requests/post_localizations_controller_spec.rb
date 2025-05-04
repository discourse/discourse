# frozen_string_literal: true

describe PostLocalizationsController do
  fab!(:user)
  fab!(:group)
  fab!(:post_record) { Fabricate(:post, version: 100) }

  let(:locale) { "ja" }
  let(:raw) { "これは翻訳です。" }

  before do
    SiteSetting.experimental_content_localization = true
    SiteSetting.experimental_content_localization_allowed_groups = group.id.to_s
    group.add(user)
    sign_in(user)
  end

  describe "#create" do
    it "creates a new localization" do
      expect {
        post "/post_localizations.json",
             params: {
               post_id: post_record.id,
               locale: locale,
               raw: raw,
             }
      }.to change { PostLocalization.count }.by(1)
      expect(response.status).to eq(201)
      localization = PostLocalization.last
      expect(localization.locale).to eq(locale)
      expect(localization.raw).to eq(raw)
      expect(localization.post_id).to eq(post_record.id)
      expect(localization.post_version).to eq(post_record.version)
      expect(localization.localizer_user_id).to eq(user.id)
    end

    it "returns forbidden if user not in allowed group" do
      group.remove(user)
      post "/post_localizations.json", params: { post_id: post_record.id, locale: locale, raw: raw }
      expect(response.status).to eq(403)
    end

    it "returns not found if post does not exist" do
      post "/post_localizations.json", params: { post_id: -1, locale: locale, raw: raw }
      expect(response.status).to eq(404)
    end
  end

  describe "#update" do
    fab!(:post_localization) { Fabricate(:post_localization, post: post_record, locale: "ja") }

    it "updates an existing localization" do
      put "/post_localizations/#{post_localization.id}.json",
          params: {
            post_id: post_record.id,
            locale: locale,
            raw: raw,
          }
      expect(response.status).to eq(200)
      expect(PostLocalization.last.raw).to eq(raw)
    end

    it "returns 404 if localization is missing" do
      put "/post_localizations.json", params: { post_id: post_record.id, locale: "de", raw: "何か" }
      expect(response.status).to eq(404)
    end
  end

  describe "#destroy" do
    fab!(:post_localization) { Fabricate(:post_localization, post: post_record, locale: "ja") }

    it "destroys the localization" do
      expect {
        delete "/post_localizations/#{post_localization.id}.json",
               params: {
                 post_id: post_record.id,
                 locale: locale,
               }
      }.to change { PostLocalization.count }.by(-1)
      expect(response.status).to eq(204)
    end

    it "returns 404 if localization is missing" do
      delete "/post_localizations/289127813837.json",
             params: {
               post_id: post_record.id,
               locale: "nope",
             }
      expect(response.status).to eq(404)
    end
  end
end
