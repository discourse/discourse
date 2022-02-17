# frozen_string_literal: true

require "rails_helper"

describe SiteSettingExtension, type: :multisite do
  before do
    MessageBus.off
  end

  after do
    MessageBus.on
  end

  let(:provider_local) do
    SiteSettings::LocalProcessProvider.new
  end

  let(:settings) do
    new_settings(provider_local)
  end

  it "has no db cross talk" do
    settings.setting(:hello, 1)
    settings.hello = 100

    test_multisite_connection("second") do
      expect(settings.hello).to eq(1)
    end
  end
end
