# frozen_string_literal: true

RSpec.describe AboutSerializer do
  fab!(:user)

  describe "localized site settings" do
    before do
      SiteSetting.content_localization_enabled = true
      SiteSetting.title = "English title"
      SiteSetting.site_description = "English description"
      SiteSetting.extended_site_description = "English **extended** description"
      SiteSetting.extended_site_description_cooked =
        PrettyText.markdown(SiteSetting.extended_site_description)

      SiteSettingLocalization.create!(setting_name: "title", locale: "ja", value: "日本語タイトル")
      SiteSettingLocalization.create!(
        setting_name: "site_description",
        locale: "ja",
        value: "日本語の説明",
      )
      SiteSettingLocalization.create!(
        setting_name: "extended_site_description",
        locale: "ja",
        value: "日本語の **詳細** 説明",
      )
    end

    it "serializes localized about content" do
      json =
        AboutSerializer.new(
          About.new(user, locale: "ja"),
          scope: Guardian.new(user),
          root: nil,
        ).as_json

      aggregate_failures do
        expect(json[:title]).to eq("日本語タイトル")
        expect(json[:description]).to eq("日本語の説明")
        expect(json[:extended_site_description]).to include("<strong>詳細</strong>")
      end
    end

    it "serializes original about content when requested" do
      json =
        AboutSerializer.new(
          About.new(user, locale: "ja", show_original: true),
          scope: Guardian.new(user),
          root: nil,
        ).as_json

      aggregate_failures do
        expect(json[:title]).to eq("English title")
        expect(json[:description]).to eq("English description")
        expect(json[:extended_site_description]).to include("<strong>extended</strong>")
      end
    end
  end

  context "when login_required is enabled" do
    before do
      SiteSetting.login_required = true
      SiteSetting.contact_url = "https://example.com/contact"
      SiteSetting.contact_email = "example@foobar.com"
    end

    it "contact details are hidden from anonymous users" do
      json = AboutSerializer.new(About.new(nil), scope: Guardian.new(nil), root: nil).as_json
      expect(json[:contact_url]).to eq(nil)
      expect(json[:contact_email]).to eq(nil)
    end

    it "contact details are visible to regular users" do
      json = AboutSerializer.new(About.new(user), scope: Guardian.new(user), root: nil).as_json
      expect(json[:contact_url]).to eq(SiteSetting.contact_url)
      expect(json[:contact_email]).to eq(SiteSetting.contact_email)
    end
  end

  context "when login_required is disabled" do
    before do
      SiteSetting.login_required = false
      SiteSetting.contact_url = "https://example.com/contact"
      SiteSetting.contact_email = "example@foobar.com"
    end

    it "contact details are visible to anonymous users" do
      json = AboutSerializer.new(About.new(nil), scope: Guardian.new(nil), root: nil).as_json
      expect(json[:contact_url]).to eq(SiteSetting.contact_url)
      expect(json[:contact_email]).to eq(SiteSetting.contact_email)
    end

    it "contact details are visible to regular users" do
      json = AboutSerializer.new(About.new(user), scope: Guardian.new(user), root: nil).as_json
      expect(json[:contact_url]).to eq(SiteSetting.contact_url)
      expect(json[:contact_email]).to eq(SiteSetting.contact_email)
    end
  end

  describe "#stats" do
    after do
      DiscoursePluginRegistry.reset_register!(:private_stat)
      DiscoursePluginRegistry.reset_register!(:exposable_stat)
    end

    let(:plugin) { Plugin::Instance.new }

    it "serialize exposable stats only" do
      Discourse.redis.del(About.stats_cache_key)

      plugin.register_stat("private_stat", expose_via_api: false) do
        { :last_day => 1, "7_days" => 2, "30_days" => 3, :count => 4 }
      end
      plugin.register_stat("exposable_stat", expose_via_api: true) do
        { :last_day => 11, "7_days" => 12, "30_days" => 13, :count => 14 }
      end

      serializer = AboutSerializer.new(About.new(user), scope: Guardian.new(user), root: nil)
      json = serializer.as_json

      stats = json[:stats]
      expect(stats["exposable_stat_last_day"]).to be(11)
      expect(stats["exposable_stat_7_days"]).to be(12)
      expect(stats["exposable_stat_30_days"]).to be(13)
      expect(stats["exposable_stat_count"]).to be(14)
      expect(stats["private_stat_last_day"]).not_to be_present
      expect(stats["private_stat_7_days"]).not_to be_present
      expect(stats["private_stat_30_days"]).not_to be_present
      expect(stats["private_stat_count"]).not_to be_present
    end
  end
end
