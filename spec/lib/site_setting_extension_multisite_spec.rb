# frozen_string_literal: true

RSpec.describe SiteSettingExtension, type: :multisite do
  before { MessageBus.off }

  after { MessageBus.on }

  let(:provider_local) { SiteSettings::LocalProcessProvider.new }

  let(:settings) { new_settings(provider_local) }

  it "has no db cross talk" do
    settings.setting(:hello, 1)
    settings.hello = 100

    test_multisite_connection("second") { expect(settings.hello).to eq(1) }
  end

  describe ".after_fork" do
    it "loads the current settings for each configured site" do
      settings.setting(:hello, 1)

      settings.hello = 100
      test_multisite_connection("second") { settings.hello = 200 }

      settings.provider.save(:hello, 111, SiteSetting.types[:integer])
      test_multisite_connection("second") do
        settings.provider.save(:hello, 222, SiteSetting.types[:integer])
      end

      settings.after_fork

      expect(settings.hello).to eq(111)
      test_multisite_connection("second") { expect(settings.hello).to eq(222) }
    end

    it "does not publish cache invalidation messages while reloading settings" do
      settings.setting(:hello, 1)
      settings.hello = 100
      settings.provider.save(:hello, 111, SiteSetting.types[:integer])
      test_multisite_connection("second") do
        settings.provider.save(:hello, 222, SiteSetting.types[:integer])
      end

      messages = MessageBus.track_publish { settings.after_fork }

      expect(messages).to eq([])
    end
  end
end
