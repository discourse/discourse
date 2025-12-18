# frozen_string_literal: true

describe TagLocalizationsController do
  fab!(:user)
  fab!(:group)
  fab!(:tag)

  let(:locale) { "ja" }
  let(:name) { "猫タグ" }
  let(:description) { "猫についてのタグです" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
    sign_in(user)
  end

  describe "#show" do
    it "allows users in allowed groups to view localizations" do
      Fabricate(:tag_localization, tag: tag, locale:)

      get "/tag_localizations/#{tag.id}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["tag_localizations"].length).to eq(1)
    end

    it "denies users not in allowed groups" do
      group.remove(user)

      get "/tag_localizations/#{tag.id}.json"

      expect(response.status).to eq(403)
    end

    it "returns 404 for non-existent tag" do
      get "/tag_localizations/-1.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#create_or_update" do
    context "when localization does not exist" do
      it "creates a new localization" do
        expect {
          post "/tag_localizations/create_or_update.json",
               params: {
                 tag_id: tag.id,
                 locale:,
                 name:,
                 description:,
               }
        }.to change { TagLocalization.count }.by(1)

        expect(response.status).to eq(201)
        localization = TagLocalization.last
        expect(localization).to have_attributes(locale:, name:, description:, tag_id: tag.id)
      end

      it "creates localization without description" do
        expect {
          post "/tag_localizations/create_or_update.json",
               params: {
                 tag_id: tag.id,
                 locale:,
                 name:,
               }
        }.to change { TagLocalization.count }.by(1)

        expect(response.status).to eq(201)
        localization = TagLocalization.last
        expect(localization.description).to be_nil
      end
    end

    context "when localization already exists" do
      it "updates the existing localization" do
        localization = Fabricate(:tag_localization, tag: tag, locale:, name: "古い猫")

        expect {
          post "/tag_localizations/create_or_update.json",
               params: {
                 tag_id: tag.id,
                 locale:,
                 name:,
                 description:,
               }
        }.not_to change { TagLocalization.count }

        expect(response.status).to eq(200)
        localization.reload
        expect(localization.name).to eq(name)
        expect(localization.description).to eq(description)
      end
    end

    it "returns forbidden if user is not in allowed group" do
      group.remove(user)

      post "/tag_localizations/create_or_update.json", params: { tag_id: tag.id, locale:, name: }

      expect(response.status).to eq(403)
    end

    it "returns not found if tag does not exist" do
      post "/tag_localizations/create_or_update.json", params: { tag_id: -1, locale:, name: }

      expect(response.status).to eq(404)
    end
  end

  describe "#destroy" do
    it "destroys the localization" do
      Fabricate(:tag_localization, tag: tag, locale:)

      expect {
        delete "/tag_localizations/destroy.json", params: { tag_id: tag.id, locale: }
      }.to change { TagLocalization.count }.by(-1)

      expect(response.status).to eq(204)
    end

    it "returns 404 if localization is missing" do
      delete "/tag_localizations/destroy.json", params: { tag_id: tag.id, locale: "nope" }

      expect(response.status).to eq(404)
    end
  end

  context "when content_localization_enabled is false" do
    before { SiteSetting.content_localization_enabled = false }

    it "denies access to show" do
      get "/tag_localizations/#{tag.id}.json"
      expect(response.status).to eq(403)
    end

    it "denies access to create_or_update" do
      post "/tag_localizations/create_or_update.json", params: { tag_id: tag.id, locale:, name: }
      expect(response.status).to eq(403)
    end

    it "denies access to destroy" do
      Fabricate(:tag_localization, tag: tag, locale:)
      delete "/tag_localizations/destroy.json", params: { tag_id: tag.id, locale: }
      expect(response.status).to eq(403)
    end
  end

  context "when tag is in a restricted tag group" do
    fab!(:restricted_group, :group)
    fab!(:tag_group) { Fabricate(:tag_group, tags: [tag]) }

    before do
      TagGroupPermission.where(tag_group: tag_group).destroy_all
      TagGroupPermission.create!(
        tag_group: tag_group,
        group_id: restricted_group.id,
        permission_type: TagGroupPermission.permission_types[:full],
      )
    end

    it "denies access to show for users who cannot see the tag" do
      get "/tag_localizations/#{tag.id}.json"
      expect(response.status).to eq(403)
    end

    it "denies access to create_or_update for users who cannot see the tag" do
      post "/tag_localizations/create_or_update.json", params: { tag_id: tag.id, locale:, name: }
      expect(response.status).to eq(403)
    end

    it "allows access when user is in the restricted group" do
      restricted_group.add(user)

      get "/tag_localizations/#{tag.id}.json"
      expect(response.status).to eq(200)
    end

    it "allows staff to access restricted tags" do
      user.update!(admin: true)

      get "/tag_localizations/#{tag.id}.json"
      expect(response.status).to eq(200)
    end
  end
end
