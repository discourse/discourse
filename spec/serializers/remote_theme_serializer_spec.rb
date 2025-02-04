# frozen_string_literal: true

RSpec.describe RemoteThemeSerializer do
  fab!(:remote_theme) do
    Fabricate(
      :remote_theme,
      about_url: "https://meta.discourse.org/t/some-theme/123",
      license_url: "https://github.com/repo/repo/LICENSE.md",
    )
  end

  describe "about_url" do
    it "returns the about_url" do
      serialized = RemoteThemeSerializer.new(remote_theme).as_json[:remote_theme]
      expect(serialized[:about_url]).to eq("https://meta.discourse.org/t/some-theme/123")
    end

    it "returns nil if the URL is not a valid URL" do
      remote_theme.update!(about_url: "todo: Put your theme's public repo or Meta topic URL here")
      serialized = RemoteThemeSerializer.new(remote_theme).as_json[:remote_theme]
      expect(serialized[:about_url]).to be_nil
    end
  end

  describe "license_url" do
    it "returns the license_url" do
      serialized = RemoteThemeSerializer.new(remote_theme).as_json[:remote_theme]
      expect(serialized[:license_url]).to eq("https://github.com/repo/repo/LICENSE.md")
    end

    it "returns nil if the URL is not a valid URL" do
      remote_theme.update!(license_url: "todo: Put your theme's LICENSE URL here")
      serialized = RemoteThemeSerializer.new(remote_theme).as_json[:remote_theme]
      expect(serialized[:license_url]).to be_nil
    end
  end
end
