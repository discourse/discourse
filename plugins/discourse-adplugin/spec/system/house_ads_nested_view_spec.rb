# frozen_string_literal: true

describe "House ads in nested replies view" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic) }
  fab!(:root_replies) { Fabricate.times(7, :post, topic: topic) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }
  fab!(:house_ad)

  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:nested_root_ads) { PageObjects::Components::NestedRootAds.new }

  before do
    enable_current_plugin
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_default_sort = "old"
    SiteSetting.house_ads_after_nth_root = 3
    SiteSetting.house_ads_after_nth_post = 2

    PluginStoreRow.create!(
      plugin_name: "discourse-adplugin",
      key: "ad-setting:nested_roots_between",
      type_name: "JSON",
      value: house_ad.name,
    )

    PluginStoreRow.create!(
      plugin_name: "discourse-adplugin",
      key: "ad-setting:post_bottom",
      type_name: "JSON",
      value: house_ad.name,
    )

    sign_in(user)
  end

  it "shows the user an ad after every nth root reply and no post-bottom ads" do
    nested_view.visit_nested(topic)

    expect(nested_view).to have_root_post(root_replies.first)
    expect(nested_root_ads).to have_ads(count: 2)
    expect(nested_root_ads).to have_ad_after(root_replies[2])
    expect(nested_root_ads).to have_ad_after(root_replies[5])
    expect(nested_root_ads).to have_no_ad_after(root_replies[0])
    expect(nested_root_ads).to have_no_post_bottom_ads
  end
end
