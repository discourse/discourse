# frozen_string_literal: true

require_relative "../../../db/migrate/20250722101702_enable_affiliate_if_already_installed"

RSpec.describe EnableAffiliateIfAlreadyInstalled do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    @provider = SiteSetting.provider
    SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
  end

  after { SiteSetting.provider = @provider }

  it "enables the affiliate plugin if it was previously installed" do
    expect(SiteSetting.affiliate_enabled).to eq(false)
    SiteSetting.affiliate_amazon_ca = "abc"

    EnableAffiliateIfAlreadyInstalled.new.up

    SiteSetting.refresh!
    expect(SiteSetting.affiliate_enabled).to eq(true)
  end

  it "leaves disabled if not configured" do
    expect(SiteSetting.affiliate_enabled).to eq(false)

    EnableAffiliateIfAlreadyInstalled.new.up

    SiteSetting.refresh!
    expect(SiteSetting.affiliate_enabled).to eq(false)
  end
end
