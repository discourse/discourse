# frozen_string_literal: true

RSpec.describe SiteSetting, ".live_file_transfer_max_size_mb" do
  it "declares the binary MiB default, bounds, dependency and client visibility" do
    settings = YAML.load_file(File.expand_path("../../../config/settings.yml", __dir__))["plugins"]
    expect(settings["live_file_transfer_max_size_mb"]).to eq(
      "type" => "integer",
      "default" => 100,
      "min" => 1,
      "max" => 102_400,
      "client" => true,
      "depends_on" => ["live_enabled"],
    )
    expect(SiteSetting.live_file_transfer_max_size_mb).to eq(100)
    expect(
      JSON.parse(SiteSetting.client_settings_json_uncached)["live_file_transfer_max_size_mb"],
    ).to eq(100)
  end

  it "accepts the boundaries and exposes a custom maximum to clients" do
    SiteSetting.live_file_transfer_max_size_mb = 1
    expect(SiteSetting.live_file_transfer_max_size_mb).to eq(1)
    SiteSetting.live_file_transfer_max_size_mb = 102_400
    expect(SiteSetting.live_file_transfer_max_size_mb).to eq(102_400)
    SiteSetting.live_file_transfer_max_size_mb = 256
    expect(
      JSON.parse(SiteSetting.client_settings_json_uncached)["live_file_transfer_max_size_mb"],
    ).to eq(256)
  end

  it "rejects values outside the configured bounds" do
    [0, -1, 102_401].each do |value|
      expect { SiteSetting.live_file_transfer_max_size_mb = value }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end
end
