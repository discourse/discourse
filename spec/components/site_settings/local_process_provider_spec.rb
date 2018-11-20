require 'rails_helper'
require_dependency 'site_settings/local_process_provider'

describe SiteSettings::LocalProcessProvider do

  def expect_same_setting(actual, expected)
    expect(actual.name).to eq(expected.name)
    expect(actual.value).to eq(expected.value)
    expect(actual.data_type).to eq(expected.data_type)
  end

  let :provider do
    SiteSettings::LocalProcessProvider.new
  end

  def setting(name, value, data_type)
    OpenStruct.new.tap do |setting|
      setting.name = name
      setting.value = value
      setting.data_type = data_type
    end
  end

  describe "all" do
    it "starts off empty" do
      expect(provider.all).to eq([])
    end

    it "can allows additional settings" do
      provider.save("test", "bla", 2)
      expect_same_setting(provider.all[0], setting("test", "bla", 2))
    end

    it "does not leak new stuff into list" do
      provider.save("test", "bla", 2)
      provider.save("test", "bla1", 2)
      expect_same_setting(provider.all[0], setting("test", "bla1", 2))
      expect(provider.all.length).to eq(1)
    end
  end

  describe "find" do
    it "starts off empty" do
      expect(provider.find("bla")).to eq(nil)
    end

    it "can find a new setting" do
      provider.save("one", "two", 3)
      expect_same_setting(provider.find("one"), setting("one", "two", 3))
    end

    it "can amend a setting" do
      provider.save("one", "three", 4)
      expect_same_setting(provider.find("one"), setting("one", "three", 4))
    end
  end

  describe "destroy" do
    it "can destroy a setting" do
      provider.save("one", "three", 4)
      provider.destroy("one")
      expect(provider.find("one")).to eq(nil)
    end
  end

  it "returns the correct site name" do
    expect(provider.current_site).to eq("test")
  end
end
