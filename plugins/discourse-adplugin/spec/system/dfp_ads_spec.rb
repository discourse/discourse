# frozen_string_literal: true

describe "DFP External Ads", type: :system do
  before { enable_current_plugin }

  fab!(:user) { Fabricate(:user, trust_level: 1) }
  fab!(:topic)

  before do
    SiteSetting.discourse_adplugin_enabled = true
    SiteSetting.dfp_publisher_id = "test_publisher_123"
    SiteSetting.dfp_through_trust_level = 2

    # Create 20 posts so we ca` n test nth post ads
    20.times { Fabricate(:post, topic: topic) }
  end

  describe "DFP ads with impression tracking" do
    before do
      SiteSetting.ad_plugin_enable_tracking = true
      SiteSetting.dfp_topic_list_top_code = "topic_list_top_ad_unit"
      SiteSetting.dfp_topic_list_top_ad_sizes = "728*90 - leaderboard"
      10.times { Fabricate(:topic) }
    end

    it "records impression when DFP ad is viewed" do
      sign_in(user)

      expect { visit "/latest" }.to change { AdPlugin::AdImpression.count }.by(1)

      impression = AdPlugin::AdImpression.last
      expect(impression.ad_type).to eq("dfp")
      expect(impression.house_ad).to be_nil
      expect(impression.placement).to eq("topic-list-top")
    end

    it "does not record impression if tracking is disabled" do
      SiteSetting.ad_plugin_enable_tracking = false
      sign_in(user)

      expect { visit "/latest" }.not_to change { AdPlugin::AdImpression.count }
    end
  end
end
