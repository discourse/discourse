# frozen_string_literal: true

RSpec.describe AboutSerializer do
  fab!(:user)

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
    after { DiscoursePluginRegistry.reset! }

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
