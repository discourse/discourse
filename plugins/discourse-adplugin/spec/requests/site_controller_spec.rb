# frozen_string_literal: true

RSpec.describe SiteController do
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:user)
  fab!(:group_2) { Fabricate(:group) }
  fab!(:user_with_group) { Fabricate(:user, group_ids: [group.id]) }

  let!(:anon_ad) do
    AdPlugin::HouseAd.create(
      name: "anon-ad",
      html: "<div>ANON</div>",
      visible_to_logged_in_users: false,
      visible_to_anons: true,
      group_ids: [],
      category_ids: [],
    )
  end

  let!(:logged_in_ad) do
    AdPlugin::HouseAd.create(
      name: "logged-in-ad",
      html: "<div>LOGGED IN</div>",
      visible_to_logged_in_users: true,
      visible_to_anons: false,
      group_ids: [],
      category_ids: [],
    )
  end

  let!(:logged_in_ad_with_category) do
    AdPlugin::HouseAd.create(
      name: "logged-in-ad-with-category",
      html: "<div>LOGGED IN WITH CATEGORY</div>",
      visible_to_logged_in_users: true,
      visible_to_anons: false,
      group_ids: [group.id],
      category_ids: [private_category.id],
    )
  end

  let!(:logged_in_ad_with_group_2) do
    AdPlugin::HouseAd.create(
      name: "logged-in-ad-with-group",
      html: "<div>LOGGED IN WITH GROUP</div>",
      visible_to_logged_in_users: true,
      visible_to_anons: false,
      group_ids: [group_2.id],
      category_ids: [],
    )
  end

  let!(:everyone_ad) do
    AdPlugin::HouseAd.create(
      name: "everyone-ad",
      html: "<div>EVERYONE</div>",
      visible_to_logged_in_users: true,
      visible_to_anons: true,
      group_ids: [],
      category_ids: [],
    )
  end

  let!(:everyone_group_ad) do
    AdPlugin::HouseAd.create(
      name: "everyone-group-ad",
      html: "<div>EVERYONE</div>",
      visible_to_logged_in_users: true,
      visible_to_anons: false,
      group_ids: [Group::AUTO_GROUPS[:everyone]],
      category_ids: [],
    )
  end

  before do
    enable_current_plugin
    AdPlugin::HouseAdSetting.update(
      "topic_list_top",
      "logged-in-ad|anon-ad|everyone-ad|logged-in-ad-with-category|logged-in-ad-with-group|everyone-group-ad",
    )
  end

  describe "#site" do
    context "when logged in" do
      it "only includes ads that are visible to logged in users" do
        sign_in(user)
        get "/site.json"
        # excluded logged_in_ad_with_group_2 and logged_in_ad_with_category
        expect(response.parsed_body["house_creatives"]["creatives"].keys).to contain_exactly(
          "logged-in-ad",
          "everyone-group-ad",
          "everyone-ad",
        )
      end

      it "includes ads that are within the logged in user's category permissions" do
        sign_in(user_with_group)
        get "/site.json"
        expect(response.parsed_body["house_creatives"]["creatives"].keys).to contain_exactly(
          "logged-in-ad",
          "everyone-group-ad",
          "logged-in-ad-with-category",
          "everyone-ad",
        )
      end
    end

    context "when anonymous" do
      it "only includes ads that are visible to anonymous users" do
        get "/site.json"
        # excludes everyone_group_ad
        expect(response.parsed_body["house_creatives"]["creatives"].keys).to contain_exactly(
          "anon-ad",
          "everyone-ad",
        )
      end

      it "invalidates cache when an ad is updated" do
        get "/site.json"
        expect(response.parsed_body["house_creatives"]["creatives"].keys).to contain_exactly(
          "anon-ad",
          "everyone-ad",
        )

        anon_ad.visible_to_anons = false
        anon_ad.save

        get "/site.json"
        expect(response.parsed_body["house_creatives"]["creatives"].keys).to contain_exactly(
          "everyone-ad",
        )
      end
    end
  end
end
