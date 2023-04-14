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
end
