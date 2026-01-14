# frozen_string_literal: true

describe AdPlugin::HouseAdSettingsController do
  let(:admin) { Fabricate(:admin) }

  before do
    enable_current_plugin
    AdPlugin::HouseAd.create(name: "Banner", html: "<p>Banner</p>")
  end

  describe "update" do
    let(:valid_params) { { value: "Banner" } }

    it "error if not logged in" do
      put "/admin/plugins/pluginad/house_settings/topic_list_top.json", params: valid_params
      expect(response.status).to eq(404)
    end

    it "error if not staff" do
      sign_in(Fabricate(:user))
      put "/admin/plugins/pluginad/house_settings/topic_list_top.json", params: valid_params
      expect(response.status).to eq(404)
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "changes the setting" do
        put "/admin/plugins/pluginad/house_settings/topic_list_top.json", params: valid_params
        expect(response.status).to eq(200)
        expect(AdPlugin::HouseAdSetting.all[:topic_list_top]).to eq(valid_params[:value])
      end

      it "errors on invalid setting name" do
        put "/admin/plugins/pluginad/house_settings/nope-nope.json", params: valid_params
        expect(response.status).to eq(404)
      end

      it "errors on invalid setting value" do
        put "/admin/plugins/pluginad/house_settings/topic_list_top.json",
            params: valid_params.merge(value: "Banner|<script>")
        expect(response.status).to eq(400)
      end
    end
  end
end
