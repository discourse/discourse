# frozen_string_literal: true

RSpec.describe SiteSettings::LocalProcessProvider, type: :multisite do
  def expect_same_setting(actual, expected)
    expect(actual.name).to eq(expected.name)
    expect(actual.value).to eq(expected.value)
    expect(actual.data_type).to eq(expected.data_type)
  end

  let(:provider) { described_class.new }

  def setting(name, value, data_type)
    described_class::Setting.new(name, data_type).tap { |s| s.value = value }
  end

  it "loads the correct settings" do
    test_multisite_connection("default") { provider.save("test", "bla-default", 2) }
    test_multisite_connection("second") { provider.save("test", "bla-second", 2) }

    test_multisite_connection("default") do
      expect_same_setting(provider.find("test"), setting("test", "bla-default", 2))
    end

    test_multisite_connection("second") do
      expect_same_setting(provider.find("test"), setting("test", "bla-second", 2))
    end
  end

  it "returns the correct site name" do
    test_multisite_connection("second") { expect(provider.current_site).to eq("second") }
  end
end
