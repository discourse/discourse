# frozen_string_literal: true

module SiteSettingsHelpers
  def new_settings(provider)
    Class.new do
      extend SiteSettingExtension
      # we want to avoid leaking a big pile of MessageBus subscriptions here (1 per class)
      # so we set listen_for_changes to false
      self.listen_for_changes = false
      self.provider = provider
    end
  end
end
