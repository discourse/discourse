# frozen_string_literal: true

module SiteSettingsHelpers
  def new_settings(provider)
    Class.new do
      extend SiteSettingExtension
      # we want to avoid leaking a big pile of MessageBus subscriptions here (1 per class)
      # so we set listen_for_changes to false
      self.listen_for_changes = false
      self.provider = provider

      def self.setting(*args)
        super
      end
    end
  end

  # GlobalSettings that affect the cache.
  ASSET_HOST_GLOBAL_SETTINGS = %i[cdn_url s3_cdn_url s3_asset_cdn_url]

  def global_setting(name, value)
    SiteSetting.hidden_settings_provider.remove_hidden(name)
    SiteSetting.shadowed_settings.delete(name)
    GlobalSetting.reset_s3_cache!
    Stylesheet::Manager.cache.clear if ASSET_HOST_GLOBAL_SETTINGS.include?(name.to_sym)

    GlobalSetting.stubs(name).returns(value)

    before_next_spec do
      SiteSetting.hidden_settings_provider.remove_hidden(name)
      SiteSetting.shadowed_settings.delete(name)
      GlobalSetting.reset_s3_cache!
      Stylesheet::Manager.cache.clear if ASSET_HOST_GLOBAL_SETTINGS.include?(name.to_sym)
    end
  end

  def set_cdn_url(cdn_url)
    global_setting :cdn_url, cdn_url
    Rails.configuration.action_controller.asset_host = cdn_url
    ActionController::Base.asset_host = cdn_url

    before_next_spec do
      Rails.configuration.action_controller.asset_host = nil
      ActionController::Base.asset_host = nil
    end
  end

  def stub_deprecated_settings!(override:)
    SiteSetting.load_settings(
      "#{Rails.root.join("spec/fixtures/site_settings/deprecated_test.yml")}",
    )

    stub_const(
      SiteSettings::DeprecatedSettings,
      "SETTINGS",
      [["old_one", "new_one", override, "0.0.1"]],
    ) do
      SiteSetting.setup_deprecated_methods
      yield
    end

    defaults = SiteSetting.defaults.instance_variable_get(:@defaults)
    defaults.each { |_, hash| hash.delete(:old_one) }
    defaults.each { |_, hash| hash.delete(:new_one) }
  end
end
