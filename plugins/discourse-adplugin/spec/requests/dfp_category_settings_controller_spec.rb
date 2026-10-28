# frozen_string_literal: true

RSpec.describe AdPlugin::DfpCategorySettingsController do
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)

  before { enable_current_plugin }

  describe "#index" do
    it "lists settings for admins" do
      setting =
        AdPlugin::DfpCategorySetting.create!(
          category: category,
          gam_adunit: "/6355419/Travel/Europe",
          gam_keywords: "travel,europe",
          gtm_taxonomy: "travel/europe",
        )
      sign_in(admin)

      get "/admin/plugins/pluginad/dfp_category_settings.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["dfp_category_settings"]).to contain_exactly(
        {
          "id" => setting.id,
          "category_id" => category.id,
          "gam_adunit" => "/6355419/Travel/Europe",
          "gam_keywords" => "travel,europe",
          "gtm_taxonomy" => "travel/europe",
        },
      )
    end

    it "is unavailable to non-admins" do
      sign_in(Fabricate(:user))

      get "/admin/plugins/pluginad/dfp_category_settings.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#create" do
    before { sign_in(admin) }

    it "creates a category setting" do
      expect {
        post "/admin/plugins/pluginad/dfp_category_settings.json",
             params: {
               category_id: category.id,
               gam_adunit: "/6355419/Travel/Europe/France/Paris",
               gam_keywords: "local-test,category-override",
               gtm_taxonomy: "local/test",
             }
      }.to change { AdPlugin::DfpCategorySetting.count }.by(1)

      expect(response.status).to eq(201)
      expect(response.parsed_body["dfp_category_setting"]["category_id"]).to eq(category.id)
    end

    it "rejects a duplicate category" do
      AdPlugin::DfpCategorySetting.create!(category: category)

      expect {
        post "/admin/plugins/pluginad/dfp_category_settings.json",
             params: {
               category_id: category.id,
               gam_adunit: "/6355419/Travel/Europe",
             }
      }.not_to change { AdPlugin::DfpCategorySetting.count }

      expect(response.status).to eq(422)
    end
  end

  describe "#update" do
    it "updates a category setting" do
      setting = AdPlugin::DfpCategorySetting.create!(category: category)
      sign_in(admin)

      put "/admin/plugins/pluginad/dfp_category_settings/#{setting.id}.json",
          params: {
            category_id: other_category.id,
            gam_adunit: "/6355419/Travel/Europe",
            gam_keywords: "travel,europe",
          }

      expect(response.status).to eq(200)
      expect(setting.reload).to have_attributes(
        category_id: other_category.id,
        gam_adunit: "/6355419/Travel/Europe",
        gam_keywords: "travel,europe",
      )
    end
  end

  describe "#destroy" do
    it "deletes a category setting" do
      setting = AdPlugin::DfpCategorySetting.create!(category: category)
      sign_in(admin)

      expect {
        delete "/admin/plugins/pluginad/dfp_category_settings/#{setting.id}.json"
      }.to change { AdPlugin::DfpCategorySetting.count }.by(-1)

      expect(response.status).to eq(204)
    end
  end

  describe "live-update signal" do
    before { sign_in(admin) }

    it "broadcasts only the public map with a secure flag, never private config" do
      public_setting =
        MessageBus.track_publish("/site/dfp-category-settings/changed") do
          post "/admin/plugins/pluginad/dfp_category_settings.json",
               params: {
                 category_id: category.id,
                 gam_adunit: "/6355419/Travel/Europe",
               }
        end

      payload = public_setting.last.data.with_indifferent_access
      expect(payload[:secure]).to eq(false)
      expect(payload[:public][category.id.to_s]["gam_adunit"]).to eq("/6355419/Travel/Europe")
    end

    it "omits private categories from the broadcast public map but flags secure config" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))

      messages =
        MessageBus.track_publish("/site/dfp-category-settings/changed") do
          post "/admin/plugins/pluginad/dfp_category_settings.json",
               params: {
                 category_id: private_category.id,
                 gam_adunit: "/6355419/private",
               }
        end

      payload = messages.last.data.with_indifferent_access
      expect(payload[:secure]).to eq(true)
      expect(payload[:public]).not_to have_key(private_category.id.to_s)
    end

    it "drops a deleted category from the broadcast" do
      setting = AdPlugin::DfpCategorySetting.create!(category: category)

      messages =
        MessageBus.track_publish("/site/dfp-category-settings/changed") do
          delete "/admin/plugins/pluginad/dfp_category_settings/#{setting.id}.json"
        end

      payload = messages.last.data.with_indifferent_access
      expect(payload[:public]).not_to have_key(category.id.to_s)
    end
  end

  describe "#map" do
    let!(:public_setting) do
      AdPlugin::DfpCategorySetting.create!(category: category, gam_adunit: "/6355419/Travel/Europe")
    end
    let!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
    let!(:private_setting) do
      AdPlugin::DfpCategorySetting.create!(
        category: private_category,
        gam_adunit: "/6355419/private",
      )
    end

    it "returns only publicly visible config to anonymous users" do
      get "/ad_plugin/dfp_category_settings.json"

      expect(response.status).to eq(200)
      map = response.parsed_body
      expect(map[category.id.to_s]["gam_adunit"]).to eq("/6355419/Travel/Europe")
      expect(map).not_to have_key(private_category.id.to_s)
    end

    it "returns secure config to users who can see those categories" do
      sign_in(admin)
      get "/ad_plugin/dfp_category_settings.json"

      expect(response.parsed_body).to have_key(private_category.id.to_s)
    end

    it "returns secure config to a non-staff member of the category group" do
      member = Fabricate(:user, trust_level: 1)
      private_category.groups.first.users << member
      sign_in(member)

      get "/ad_plugin/dfp_category_settings.json"

      expect(response.parsed_body).to have_key(private_category.id.to_s)
    end

    it "withholds secure config from a logged-in user without access" do
      sign_in(Fabricate(:user, trust_level: 1))

      get "/ad_plugin/dfp_category_settings.json"

      expect(response.parsed_body).not_to have_key(private_category.id.to_s)
    end
  end

  describe "admin SPA HTML routes" do
    before { sign_in(admin) }

    it "serves the app shell for the dashboard deep links (direct visit / reload)" do
      setting = AdPlugin::DfpCategorySetting.create!(category: category)

      [
        "/admin/plugins/discourse-adplugin/dfp-settings",
        "/admin/plugins/discourse-adplugin/dfp-settings/new",
        "/admin/plugins/discourse-adplugin/dfp-settings/#{setting.id}/edit",
      ].each do |path|
        get path
        expect(response.status).to eq(200)
      end
    end
  end
end
