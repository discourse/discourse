# frozen_string_literal: true

RSpec.describe AdminPluginSerializer do
  subject(:serializer) { described_class.new(instance) }

  let(:all_test_plugins) { Plugin::Instance.find_all("#{Rails.root}/spec/fixtures/plugins") }
  let(:instance) { all_test_plugins.find { |plugin| plugin.name == "color_definition" } }

  describe "admin_route" do
    it "returns the correct values when use_new_show_route is false" do
      instance.expects(:admin_route).returns(
        location: "admin",
        label: "admin.test",
        use_new_show_route: false,
      )
      expect(serializer.admin_route).to eq(
        location: "admin",
        label: "admin.test",
        full_location: "adminPlugins.admin",
        use_new_show_route: false,
      )
    end

    it "returns the correct values when use_new_show_route is true" do
      instance.expects(:admin_route).returns(
        location: "admin",
        label: "admin.test",
        use_new_show_route: true,
      )
      expect(serializer.admin_route).to eq(
        location: "admin",
        label: "admin.test",
        full_location: "adminPlugins.show",
        use_new_show_route: true,
      )
    end
  end

  describe "has_settings" do
    it "is false for plugins with no settings" do
      expect(described_class.new(instance).has_settings).to eq(false)
    end

    it "is true for plugins with settings" do
      SiteSetting.expects(:plugins).returns(
        {
          "color_definition_enabled" => "color_definition",
          "color_definition_api_key" => "color_definition",
        },
      )
      expect(described_class.new(instance).has_settings).to eq(true)
    end
  end

  describe "has_only_enabled_settings" do
    it "is false for plugins with no settings" do
      expect(described_class.new(instance).has_settings).to eq(false)
    end

    it "is true if only enabled_site_setting is present for the plugin" do
      SiteSetting.expects(:plugins).returns({ "color_definition_enabled" => "color_definition" })
      expect(described_class.new(instance).has_settings).to eq(true)
    end

    it "is false if there are other settings for the plugin" do
      SiteSetting.expects(:plugins).returns(
        {
          "color_definition_enabled" => "color_definition",
          "color_definition_api_key" => "color_definition",
        },
      )
      expect(described_class.new(instance).has_only_enabled_setting).to eq(false)
    end
  end

  describe "enabled_setting" do
    it "should return the right value" do
      instance.enabled_site_setting("test")
      expect(serializer.enabled_setting).to eq("test")
    end
  end

  describe "commit_hash" do
    it "should return commit_hash and commit_url" do
      git_repo = instance.git_repo
      git_repo.stubs(:latest_local_commit).returns("123456")
      git_repo.stubs(:url).returns("http://github.com/discourse/discourse-plugin")

      expect(serializer.commit_hash).to eq("123456")
      expect(serializer.commit_url).to eq(
        "http://github.com/discourse/discourse-plugin/commit/123456",
      )
    end
  end
end
