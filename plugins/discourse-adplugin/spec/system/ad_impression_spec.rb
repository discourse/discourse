# frozen_string_literal: true

describe "AdPlugin::AdImpression", type: :system do
  before { enable_current_plugin }

  describe "when a user sees an ad" do
    fab!(:house_ad)

    before do
      SiteSetting.house_ads_after_nth_topic = 1
      SiteSetting.ad_plugin_enable_tracking = true
      10.times { Fabricate(:topic) }

      PluginStoreRow.create!(
        plugin_name: "discourse-adplugin",
        key: "ad-setting:topic_list_between",
        type_name: "JSON",
        value: house_ad.name,
      )
    end

    it "records the impression appropriately" do
      visit "/latest"

      impression = AdPlugin::AdImpression.last

      expect(impression.house_ad).to eq(house_ad)
    end
  end

  describe "house ad impression tracking visibility" do
    fab!(:house_ad)

    before do
      SiteSetting.ad_plugin_enable_tracking = true
      SiteSetting.house_ads_after_nth_topic = 20
      20.times { Fabricate(:topic) }

      AdPlugin::HouseAdSetting.all["topic_list_between"] = house_ad.name
      AdPlugin::HouseAdSetting.publish_settings

      PluginStoreRow.create!(
        plugin_name: "discourse-adplugin",
        key: "ad-setting:topic_list_between",
        type_name: "JSON",
        value: house_ad.name,
      )
    end

    it "does not record impression before scrolling into view" do
      visit "/latest"

      expect(AdPlugin::AdImpression.count).to eq(0)

      page.execute_script("window.scrollTo(0, document.body.scrollHeight);")

      wait_for { AdPlugin::AdImpression.count == 1 }

      impression = AdPlugin::AdImpression.last
      expect(impression.house_ad).to eq(house_ad)
    end
  end

  describe "house ad impression tracking respects site setting" do
    fab!(:house_ad)

    before do
      10.times { Fabricate(:topic) }
      SiteSetting.ad_plugin_enable_tracking = false
      SiteSetting.house_ads_after_nth_topic = 1

      AdPlugin::HouseAdSetting.all["topic_list_between"] = house_ad.name
      AdPlugin::HouseAdSetting.publish_settings
    end

    it "does not record an impression when ad_plugin_enable_tracking is false" do
      visit "/latest"

      page.execute_script("window.scrollTo(0, document.body.scrollHeight);")

      expect(AdPlugin::AdImpression.count).to eq(0)
    end
  end
end
