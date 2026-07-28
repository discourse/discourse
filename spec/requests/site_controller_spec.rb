# frozen_string_literal: true

RSpec.describe SiteController do
  describe "#site" do
    fab!(:staff_group) { Group[:staff] }
    fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
    fab!(:public_category, :category)

    # Tags anonymous users are allowed to see.
    fab!(:visible_tag) do
      Fabricate(:tag, name: "visible-tag", description: "visible tag description")
    end
    fab!(:public_category_tag) do
      Fabricate(:tag, name: "public-category-tag", description: "public category tag description")
    end

    # Tags anonymous users must not see, one per restriction mechanism.
    fab!(:category_restricted_tag) do
      Fabricate(
        :tag,
        name: "category-restricted-tag",
        description: "category restricted tag description",
      )
    end
    fab!(:category_tag_group_restricted_tag) do
      Fabricate(
        :tag,
        name: "category-tag-group-restricted-tag",
        description: "category tag group restricted tag description",
      )
    end
    fab!(:permission_restricted_tag) do
      Fabricate(
        :tag,
        name: "permission-restricted-tag",
        description: "permission restricted tag description",
      )
    end

    fab!(:category_restricted_tag_group) do
      Fabricate(:tag_group, tags: [category_tag_group_restricted_tag])
    end
    fab!(:staff_tag_group) do
      Fabricate(
        :tag_group,
        permissions: {
          "staff" => 1,
        },
        tag_names: [permission_restricted_tag.name],
      )
    end

    before do
      CategoryTag.create!(category: public_category, tag: public_category_tag)
      CategoryTag.create!(category: private_category, tag: category_restricted_tag)
      CategoryTagGroup.create!(category: private_category, tag_group: category_restricted_tag_group)

      SiteSetting.default_navigation_menu_tags = [
        visible_tag,
        public_category_tag,
        category_restricted_tag,
        category_tag_group_restricted_tag,
        permission_restricted_tag,
      ].map(&:name).join("|")
    end

    it "serializes only the tags anonymous users are allowed to see" do
      get "/site.json"

      expect(response.status).to eq(200)
      serialized_tags = response.parsed_body.fetch("anonymous_default_navigation_menu_tags")
      expect(
        serialized_tags.map { |serialized_tag| serialized_tag.values_at("name", "description") },
      ).to contain_exactly(
        [visible_tag.name, visible_tag.description],
        [public_category_tag.name, public_category_tag.description],
      )
    end
  end

  describe "#basic_info" do
    it "is visible always even for sites requiring login" do
      upload = Fabricate(:upload)

      SiteSetting.login_required = true
      SiteSetting.title = "Hammer Time"
      SiteSetting.site_description = "A time for Hammer"
      SiteSetting.logo = upload
      SiteSetting.logo_small = upload
      SiteSetting.apple_touch_icon = upload
      SiteSetting.mobile_logo = upload
      SiteSetting.include_in_discourse_discover = true
      Theme.clear_default!

      get "/site/basic-info.json"
      json = response.parsed_body

      expected_url = UrlHelper.absolute(upload.url)

      expect(json["title"]).to eq("Hammer Time")
      expect(json["description"]).to eq("A time for Hammer")
      expect(json["logo_url"]).to eq(expected_url)
      expect(json["apple_touch_icon_url"]).to eq(expected_url)
      expect(json["logo_small_url"]).to eq(expected_url)
      expect(json["mobile_logo_url"]).to eq(expected_url)
      expect(json["header_primary_color"]).to eq("333")
      expect(json["header_background_color"]).to eq("fff")
      expect(json["login_required"]).to eq(true)
      expect(json["locale"]).to eq("en")
      expect(json["include_in_discourse_discover"]).to eq(true)
    end

    it "includes false values for include_in_discourse_discover and login_required" do
      SiteSetting.include_in_discourse_discover = false
      SiteSetting.login_required = false

      get "/site/basic-info.json"
      json = response.parsed_body

      expect(json["include_in_discourse_discover"]).to eq(false)
      expect(json["login_required"]).to eq(false)
    end
  end

  describe "#banner" do
    fab!(:admin)
    fab!(:group)
    fab!(:private_category) { Fabricate(:private_category, group: group) }

    before { ApplicationLayoutPreloader.banner_json_cache.clear }
    after { ApplicationLayoutPreloader.banner_json_cache.clear }

    it "does not expose banner content from a read-restricted category to anonymous users" do
      topic = Fabricate(:topic, category: private_category, archetype: Archetype.banner)
      Fabricate(:post, topic: topic, raw: "secret banner content")

      get "/site/banner.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json).to eq({})
    end

    it "does not expose banner content from a read-restricted category to regular users" do
      user = Fabricate(:user)
      topic = Fabricate(:topic, category: private_category, archetype: Archetype.banner)
      Fabricate(:post, topic: topic, raw: "secret banner content")

      sign_in(user)
      get "/site/banner.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json).to eq({})
    end
  end

  describe "#statistics" do
    after { DiscoursePluginRegistry.reset! }

    it "is visible for sites requiring login" do
      SiteSetting.login_required = true
      SiteSetting.share_anonymized_statistics = true

      get "/site/statistics.json"
      json = response.parsed_body

      expect(response.status).to eq(200)
      expect(json["topics_count"]).to be_present
      expect(json["posts_count"]).to be_present
      expect(json["users_count"]).to be_present
      expect(json["topics_7_days"]).to be_present
      expect(json["topics_30_days"]).to be_present
      expect(json["posts_7_days"]).to be_present
      expect(json["posts_30_days"]).to be_present
      expect(json["users_7_days"]).to be_present
      expect(json["users_30_days"]).to be_present
      expect(json["active_users_7_days"]).to be_present
      expect(json["active_users_30_days"]).to be_present
      expect(json["likes_count"]).to be_present
      expect(json["likes_7_days"]).to be_present
      expect(json["likes_30_days"]).to be_present
      expect(json["participating_users_7_days"]).to be_present
      expect(json["participating_users_30_days"]).to be_present
    end

    it "is not visible if site setting share_anonymized_statistics is disabled" do
      SiteSetting.share_anonymized_statistics = false

      get "/site/statistics.json"
      expect(response).to redirect_to "/"
    end

    it "returns exposable stats only" do
      Discourse.redis.del(About.stats_cache_key)

      SiteSetting.login_required = true
      SiteSetting.share_anonymized_statistics = true

      plugin = Plugin::Instance.new
      plugin.register_stat("private_stat", expose_via_api: false) do
        { :last_day => 1, "7_days" => 2, "30_days" => 3, :count => 4 }
      end
      plugin.register_stat("exposable_stat", expose_via_api: true) do
        { :last_day => 11, "7_days" => 12, "30_days" => 13, :count => 14 }
      end

      get "/site/statistics.json"
      json = response.parsed_body

      expect(json["exposable_stat_last_day"]).to be(11)
      expect(json["exposable_stat_7_days"]).to be(12)
      expect(json["exposable_stat_30_days"]).to be(13)
      expect(json["exposable_stat_count"]).to be(14)
      expect(json["private_stat_last_day"]).not_to be_present
      expect(json["private_stat_7_days"]).not_to be_present
      expect(json["private_stat_30_days"]).not_to be_present
      expect(json["private_stat_count"]).not_to be_present
    end
  end
end
