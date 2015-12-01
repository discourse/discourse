require 'rails_helper'
require_dependency 'site_settings/db_provider'

describe SiteSettings::DbProvider do

  def expect_same_setting(actual, expected)
    expect(actual.name).to eq(expected.name)
    expect(actual.value).to eq(expected.value)
    expect(actual.data_type).to eq(expected.data_type)
  end

  let :provider do
    SiteSettings::DbProvider.new(SiteSetting)
  end

  # integration test, requires db access
  it "act correctly" do
    setting = Struct.new(:name, :value, :data_type)

    SiteSetting.destroy_all

    expect(provider.all.length).to eq(0)
    expect(provider.find("test")).to eq(nil)


    provider.save("test", "one", 1)
    found = provider.find("test")

    expect_same_setting(found, setting.new("test", "one", 1))

    provider.save("test", "two", 2)
    found = provider.find("test")

    expect_same_setting(found, setting.new("test", "two", 2))

    provider.save("test2", "three", 3)

    all = provider.all.sort{|a,b| a.name <=> b.name}

    expect_same_setting(all[0], setting.new("test", "two", 2))
    expect_same_setting(all[1], setting.new("test2", "three", 3))
    expect(all.length).to eq(2)

    provider.destroy("test")
    expect(provider.all.length).to eq(1)
  end

  it "returns the correct site name" do
    expect(provider.current_site).to eq(RailsMultisite::ConnectionManagement.current_db)
  end
end
