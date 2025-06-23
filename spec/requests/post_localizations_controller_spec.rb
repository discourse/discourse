# frozen_string_literal: true

describe PostLocalizationsController do
  fab!(:user)
  fab!(:group)
  fab!(:post_record) { Fabricate(:post, version: 100) }

  let(:locale) { "ja" }
  let(:raw) { "これは翻訳です。" }

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
          post "/post_localizations/create_or_update.json",
               params: {
                 post_id: post_record.id,
                 locale: locale,
                 raw: raw,
               }
        }.to change { PostLocalization.count }.by(1)

        expect(response.status).to eq(201)
        localization = PostLocalization.last
        expect(localization).to have_attributes(
          locale: locale,
          raw: raw,
          post_id: post_record.id,
          post_version: post_record.version,
          localizer_user_id: user.id,
        )
      end
    end

    context "when localization already exists" do
      it "updates the existing localization" do
        localization = Fabricate(:post_localization, post: post_record, locale: locale, raw: "古い翻訳")
        new_user = Fabricate(:user, groups: [group])
        sign_in(new_user)

        expect {
          post "/post_localizations/create_or_update.json",
               params: {
                 post_id: post_record.id,
                 locale: locale,
                 raw: raw,
               }
        }.not_to change { PostLocalization.count }

        expect(response.status).to eq(200)
        localization.reload
        expect(localization.raw).to eq(raw)
        expect(localization.localizer_user_id).to eq(new_user.id)
      end
    end

    it "returns forbidden if user is not in allowed group" do
      group.remove(user)

      post "/post_localizations/create_or_update.json",
           params: {
             post_id: post_record.id,
             locale: locale,
             raw: raw,
           }

      expect(response.status).to eq(403)
    end

    it "returns not found if post does not exist" do
      post "/post_localizations/create_or_update.json",
           params: {
             post_id: -1,
             locale: locale,
             raw: raw,
           }

      expect(response.status).to eq(404)
    end
  end

  describe "#destroy" do
    it "destroys the localization" do
      Fabricate(:post_localization, post: post_record, locale: locale)

      expect {
        delete "/post_localizations/destroy.json",
               params: {
                 post_id: post_record.id,
                 locale: locale,
               }
      }.to change { PostLocalization.count }.by(-1)

      expect(response.status).to eq(204)
    end

    it "returns 404 if localization is missing" do
      delete "/post_localizations/destroy.json", params: { post_id: post_record.id, locale: "nope" }

      expect(response.status).to eq(404)
    end
  end
end
