# frozen_string_literal: true

describe AdPlugin::HouseAdsController do
  let(:admin) { Fabricate(:admin) }
  let(:category) { Fabricate(:category) }
  let(:group) { Fabricate(:group) }

  let!(:ad) do
    AdPlugin::HouseAd.create(
      name: "Banner",
      html: "<p>Banner</p>",
      visible_to_anons: true,
      visible_to_logged_in_users: false,
      category_ids: [],
      group_ids: [],
    )
  end

  before { enable_current_plugin }
  before { SiteSetting.ad_plugin_routes_enabled = true }

  describe "#create" do
    context "when used by admins" do
      before { sign_in(admin) }

      it "strips script tags from html on create" do
        post "/admin/plugins/pluginad/house_creatives.json",
             params: {
               name: "XSS Ad",
               html: '<div>Ad</div><script>alert("xss")</script>',
               visible_to_anons: "true",
               visible_to_logged_in_users: "true",
             }
        expect(response.status).to eq(200)

        created_ad = AdPlugin::HouseAd.find_by(name: "XSS Ad")
        expect(created_ad.html).not_to include("<script>")
        expect(created_ad.html).to include("<div>Ad</div>")
      end

      it "strips event handler attributes from html on create" do
        post "/admin/plugins/pluginad/house_creatives.json",
             params: {
               name: "Event Ad",
               html:
                 '<img src="x" onerror="alert(1)"><a onclick="alert(1)" href="https://example.com">Click</a>',
               visible_to_anons: "true",
               visible_to_logged_in_users: "true",
             }
        expect(response.status).to eq(200)

        created_ad = AdPlugin::HouseAd.find_by(name: "Event Ad")
        expect(created_ad.html).not_to include("onerror")
        expect(created_ad.html).not_to include("onclick")
      end
    end
  end

  describe "#update" do
    context "when used by admins" do
      before { sign_in(admin) }

      it "strips script tags from html on update" do
        put "/admin/plugins/pluginad/house_creatives/#{ad.id}.json",
            params: {
              name: ad.name,
              html: '<div>Safe</div><script>fetch("/admin/users/1/grant_admin")</script>',
              visible_to_anons: "true",
              visible_to_logged_in_users: "false",
            }
        expect(response.status).to eq(200)

        ad.reload
        expect(ad.html).not_to include("<script>")
        expect(ad.html).to include("<div>Safe</div>")
      end

      it "strips event handler attributes from html on update" do
        put "/admin/plugins/pluginad/house_creatives/#{ad.id}.json",
            params: {
              name: ad.name,
              html: '<img src="x" onerror="alert(document.cookie)">',
              visible_to_anons: "true",
              visible_to_logged_in_users: "false",
            }
        expect(response.status).to eq(200)

        ad.reload
        expect(ad.html).not_to include("onerror")
      end

      it "updates an existing ad" do
        put "/admin/plugins/pluginad/house_creatives/#{ad.id}.json",
            params: {
              name: ad.name,
              html: ad.html,
              visible_to_anons: "false",
              visible_to_logged_in_users: "true",
              category_ids: [category.id],
              group_ids: [group.id],
              routes: %w[discovery.latest topic.show],
            }
        expect(response.status).to eq(200)

        house_ad_response = JSON.parse(response.body, symbolize_names: true)[:house_ad]
        expect(house_ad_response[:id]).to eq(ad.id)
        expect(house_ad_response[:name]).to eq(ad.name)
        expect(house_ad_response[:html]).to eq(ad.html)
        expect(house_ad_response[:visible_to_anons]).to eq(false)
        expect(house_ad_response[:visible_to_logged_in_users]).to eq(true)
        expect(house_ad_response[:routes]).to contain_exactly("discovery.latest", "topic.show")

        serialized_category =
          BasicCategorySerializer.new(category, scope: Guardian.new(admin)).as_json
        expect(house_ad_response[:categories].length).to eq(1)
        expect(house_ad_response[:categories][0]).to eq(serialized_category[:basic_category])

        serialized_group = BasicGroupSerializer.new(group, scope: Guardian.new(admin)).as_json

        expect(house_ad_response[:groups].length).to eq(1)
        expect(house_ad_response[:groups][0]).to eq(serialized_group[:basic_group])

        ad_copy = AdPlugin::HouseAd.find(ad.id)
        expect(ad_copy.name).to eq(ad.name)
        expect(ad_copy.html).to eq(ad.html)
        expect(ad_copy.visible_to_anons).to eq(false)
        expect(ad_copy.visible_to_logged_in_users).to eq(true)
        expect(ad_copy.category_ids).to eq([category.id])
        expect(ad_copy.group_ids).to eq([group.id])
        expect(ad_copy.route_names).to contain_exactly("discovery.latest", "topic.show")
      end

      it "replaces routes on update" do
        ad.routes.create!(route_name: "discovery.latest")

        put "/admin/plugins/pluginad/house_creatives/#{ad.id}.json",
            params: {
              name: ad.name,
              html: ad.html,
              visible_to_anons: ad.visible_to_anons.to_s,
              visible_to_logged_in_users: ad.visible_to_logged_in_users.to_s,
              category_ids: [],
              group_ids: [],
              routes: ["discovery.top"],
            }

        expect(response.status).to eq(200)

        ad_copy = AdPlugin::HouseAd.find(ad.id)
        expect(ad_copy.reload.route_names).to eq(["discovery.top"])
      end
    end

    context "when used by non-admins" do
      before { sign_in(Fabricate(:user)) }

      it "can't update ads" do
        put "/admin/plugins/pluginad/house_creatives/#{ad.id}.json",
            params: {
              name: "non sense goes here",
              html: "blah <h4cked>",
              visible_to_anons: "false",
              visible_to_logged_in_users: "true",
              group_ids: [group.id],
              category_ids: [category.id],
              routes: ["discovery.top"],
            }
        expect(response.status).to eq(404)

        ad_copy = AdPlugin::HouseAd.find(ad.id)
        expect(ad_copy.name).to eq(ad.name)
        expect(ad_copy.html).to eq(ad.html)
        expect(ad_copy.visible_to_anons).to eq(true)
        expect(ad_copy.visible_to_logged_in_users).to eq(false)
        expect(ad_copy.category_ids).to eq([])
        expect(ad_copy.group_ids).to eq([])
        expect(ad_copy.route_names).to eq([])
      end
    end
  end
end
