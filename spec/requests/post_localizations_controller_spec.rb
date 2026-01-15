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

  describe "#show" do
    it "allows users in allowed groups to view localizations" do
      Fabricate(:post_localization, post: post_record, locale:)

      get "/post_localizations/#{post_record.id}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["post_localizations"].length).to eq(1)
    end

    it "denies users not in allowed groups" do
      group.remove(user)

      get "/post_localizations/#{post_record.id}.json"

      expect(response.status).to eq(403)
    end

    context "with author localization enabled" do
      fab!(:author, :user)
      fab!(:author_post) { Fabricate(:post, user: author) }

      before do
        SiteSetting.content_localization_allow_author_localization = true
        group.remove(author)
      end

      it "allows post authors to view localizations for their own posts" do
        Fabricate(:post_localization, post: author_post, locale:)
        sign_in(author)

        get "/post_localizations/#{author_post.id}.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["post_localizations"].length).to eq(1)
      end

      it "denies post authors from viewing localizations for others' posts" do
        Fabricate(:post_localization, post: post_record, locale:)
        sign_in(author)

        get "/post_localizations/#{post_record.id}.json"

        expect(response.status).to eq(403)
      end
    end
  end

  describe "#create_or_update" do
    context "when localization does not exist" do
      it "creates a new localization" do
        expect {
          post "/post_localizations/create_or_update.json",
               params: {
                 post_id: post_record.id,
                 locale:,
                 raw:,
               }
        }.to change { PostLocalization.count }.by(1)

        expect(response.status).to eq(201)
        localization = PostLocalization.last
        expect(localization).to have_attributes(
          locale:,
          raw:,
          post_id: post_record.id,
          post_version: post_record.version,
          localizer_user_id: user.id,
        )
      end
    end

    context "when localization already exists" do
      it "updates the existing localization" do
        localization = Fabricate(:post_localization, post: post_record, locale:, raw: "古い翻訳")
        new_user = Fabricate(:user, groups: [group])
        sign_in(new_user)

        expect {
          post "/post_localizations/create_or_update.json",
               params: {
                 post_id: post_record.id,
                 locale:,
                 raw:,
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
             locale:,
             raw:,
           }

      expect(response.status).to eq(403)
    end

    it "returns not found if post does not exist" do
      post "/post_localizations/create_or_update.json", params: { post_id: -1, locale:, raw: }

      expect(response.status).to eq(404)
    end
  end

  describe "#destroy" do
    it "destroys the localization" do
      Fabricate(:post_localization, post: post_record, locale:)

      expect {
        delete "/post_localizations/destroy.json", params: { post_id: post_record.id, locale: }
      }.to change { PostLocalization.count }.by(-1)

      expect(response.status).to eq(204)
    end

    it "returns 404 if localization is missing" do
      delete "/post_localizations/destroy.json", params: { post_id: post_record.id, locale: "nope" }

      expect(response.status).to eq(404)
    end
  end

  context "with author localization" do
    fab!(:author, :user)
    fab!(:author_post) { Fabricate(:post, user: author, version: 100) }
    fab!(:other_user, :user)

    before { group.remove(author) }

    describe "#create_or_update for post authors" do
      it "allows post author to create localization on their own post" do
        sign_in(author)

        SiteSetting.content_localization_allow_author_localization = false
        expect {
          post "/post_localizations/create_or_update.json",
               params: {
                 post_id: author_post.id,
                 locale:,
                 raw:,
               }
        }.not_to change { PostLocalization.count }

        SiteSetting.content_localization_allow_author_localization = true
        expect {
          post "/post_localizations/create_or_update.json",
               params: {
                 post_id: author_post.id,
                 locale:,
                 raw:,
               }
        }.to change { PostLocalization.count }.by(1)
        expect(response.status).to eq(201)
        localization = PostLocalization.last
        expect(localization.localizer_user_id).to eq(author.id)
      end

      it "denies post author from creating localization on others' posts" do
        SiteSetting.content_localization_allow_author_localization = true
        sign_in(author)

        expect {
          post "/post_localizations/create_or_update.json",
               params: {
                 post_id: post_record.id,
                 locale:,
                 raw:,
               }
        }.not_to change { PostLocalization.count }

        expect(response.status).to eq(403)
      end

      it "allows author to update their own localization" do
        localization =
          Fabricate(
            :post_localization,
            post: author_post,
            locale:,
            raw: "古い翻訳",
            localizer_user_id: author.id,
          )
        sign_in(author)

        SiteSetting.content_localization_allow_author_localization = false
        expect {
          post "/post_localizations/create_or_update.json",
               params: {
                 post_id: author_post.id,
                 locale:,
                 raw:,
               }
        }.not_to change { localization.reload.raw }

        SiteSetting.content_localization_allow_author_localization = true
        post "/post_localizations/create_or_update.json",
             params: {
               post_id: author_post.id,
               locale:,
               raw:,
             }
        expect(response.status).to eq(200)
        localization.reload
        expect(localization.raw).to eq(raw)
      end
    end

    describe "#destroy for post authors" do
      it "allows author to delete their own localization" do
        Fabricate(:post_localization, post: author_post, locale:, localizer_user_id: author.id)
        sign_in(author)

        SiteSetting.content_localization_allow_author_localization = false
        expect {
          delete "/post_localizations/destroy.json", params: { post_id: author_post.id, locale: }
        }.not_to change { PostLocalization.count }

        SiteSetting.content_localization_allow_author_localization = true
        expect {
          delete "/post_localizations/destroy.json", params: { post_id: author_post.id, locale: }
        }.to change { PostLocalization.count }.by(-1)

        expect(response.status).to eq(204)
      end
    end

    it "allows users in allowed groups full access regardless of author setting" do
      localization =
        Fabricate(:post_localization, post: author_post, locale:, localizer_user_id: author.id)
      sign_in(user)

      SiteSetting.content_localization_allow_author_localization = false
      expect {
        post "/post_localizations/create_or_update.json",
             params: {
               post_id: author_post.id,
               locale:,
               raw: "1",
             }
      }.to change { localization.reload.raw }

      SiteSetting.content_localization_allow_author_localization = true
      expect {
        post "/post_localizations/create_or_update.json",
             params: {
               post_id: author_post.id,
               locale:,
               raw: "2",
             }
      }.to change { localization.reload.raw }
    end
  end
end
