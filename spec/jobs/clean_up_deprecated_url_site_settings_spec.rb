# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::CleanUpDeprecatedUrlSiteSettings do
  before do
    @original_provider = SiteSetting.provider
    SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
  end

  after do
    SiteSetting.delete_all
    SiteSetting.provider = @original_provider
  end

  it 'should clean up the old deprecated site settings correctly' do
    logo_upload = Fabricate(:upload)
    SiteSetting.logo = logo_upload
    SiteSetting.set("logo_url", '/test/some/url', warn: false)
    SiteSetting.set("logo_small_url", '/test/another/url', warn: false)

    expect do
      described_class.new.execute({})
    end.to change { SiteSetting.logo_url }.from("/test/some/url").to("")

    expect(SiteSetting.exists?(name: "logo_url")).to eq(false)
    expect(SiteSetting.logo).to eq(logo_upload)
    expect(SiteSetting.logo_small_url).to eq('/test/another/url')
  end
end
