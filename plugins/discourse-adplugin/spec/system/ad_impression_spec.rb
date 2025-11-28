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

  describe "house ad click tracking" do
    fab!(:house_ad) do
      Fabricate(
        :house_ad,
        html:
          '<a href="https://example.com/product" id="test-ad-link">Click here for great deals!</a>',
      )
    end

    let(:wait_for_impression) do
      wait_for { AdPlugin::AdImpression.count == 1 }
      AdPlugin::AdImpression.last
    end

    def prevent_link_navigation
      page.execute_script(<<~JS)
        document.addEventListener("click", function(e) {
          const a = e.target.closest("a");
          if (a) {
            e.preventDefault();
          }
        }, true);
      JS
    end

    before do
      SiteSetting.house_ads_after_nth_topic = 9
      SiteSetting.ad_plugin_enable_tracking = true
      10.times { Fabricate(:topic) }

      PluginStoreRow.create!(
        plugin_name: "discourse-adplugin",
        key: "ad-setting:topic_list_between",
        type_name: "JSON",
        value: house_ad.name,
      )
    end

    it "records a click when user clicks on a link in the house ad" do
      visit "/latest"

      impression = wait_for_impression
      prevent_link_navigation

      expect(impression.clicked_at).to be_nil

      find("#test-ad-link").click
      wait_for { impression.reload.clicked_at.present? }

      expect(impression.clicked?).to eq(true)
      expect(impression.clicked_at).to be_within(5.seconds).of(Time.zone.now)
    end

    it "does not track clicks on non-link elements in house ads" do
      house_ad_with_text =
        Fabricate(:house_ad, html: '<div id="test-ad-div">Just text, no link</div>')

      PluginStoreRow.find_by(
        plugin_name: "discourse-adplugin",
        key: "ad-setting:topic_list_between",
      ).update!(value: house_ad_with_text.name)

      visit "/latest"

      impression = wait_for_impression
      find("#test-ad-div").click

      impression.reload
      expect(impression.clicked_at).to be_nil
    end

    it "only records one click per impression even with multiple clicks" do
      visit "/latest"

      impression = wait_for_impression
      prevent_link_navigation

      expect(page).to have_css("#test-ad-link")

      find("#test-ad-link").click
      wait_for { impression.reload.clicked_at.present? }

      first_click_time = impression.clicked_at

      find("#test-ad-link").click

      impression.reload
      expect(impression.clicked_at).to eq_time(first_click_time)
    end

    it "does not track clicks when ad_plugin_enable_tracking is false" do
      SiteSetting.ad_plugin_enable_tracking = false

      visit "/latest"

      expect(AdPlugin::AdImpression.count).to eq(0)

      prevent_link_navigation

      find("#test-ad-link").click

      expect(AdPlugin::AdImpression.count).to eq(0)
    end
  end
end
