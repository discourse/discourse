# frozen_string_literal: true

RSpec.describe DiscourseIpInfo do
  describe ".mmdb_download" do
    before { Discourse::Utils.stubs(:execute_command) }

    it "should download the MaxMind databases from MaxMind's download permalinks when `maxmind_license_key` and `maxmind_account_id` global setting has been set" do
      global_setting :maxmind_license_key, "license_key"
      global_setting :maxmind_account_id, "account_id"

      stub_request(
        :get,
        "https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz",
      ).with(basic_auth: %w[account_id license_key]).to_return(
        status: 302,
        body: "",
        headers: {
          location:
            "https://mm-prod-geoip-databases.a2649acb697e2c09b632799562c076f2.r2.cloudflarestorage.com/some-path",
        },
      )

      stub_request(
        :get,
        "https://mm-prod-geoip-databases.a2649acb697e2c09b632799562c076f2.r2.cloudflarestorage.com/some-path",
      ).with { |req| expect(req.headers.key?("Authorization")).to eq(false) }.to_return(status: 200)

      described_class.mmdb_download("GeoLite2-City")
    end

    it "should download the MaxMind databases from MaxMind's undocumented download URL when `maxmind_license_key` global setting has been set but not `maxmind_account_id` for backwards compatibility reasons" do
      global_setting :maxmind_license_key, "license_key"

      stub_request(
        :get,
        "https://download.maxmind.com/app/geoip_download?license_key=license_key&edition_id=GeoLite2-City&suffix=tar.gz",
      ).to_return(status: 200, body: "", headers: {})

      described_class.mmdb_download("GeoLite2-City")
    end

    it "should download the MaxMind databases from the right URL when `maxmind_mirror_url` global setting has been configured" do
      global_setting :maxmind_mirror_url, "https://b.www.example.com/mirror"

      stub_request(:get, "https://b.www.example.com/mirror/GeoLite2-City.tar.gz").to_return(
        status: 200,
        body: "",
      )

      described_class.mmdb_download("GeoLite2-City")
    end

    it "should download the MaxMind databases from the right URL when `maxmind_mirror_url` global setting has been configured and has a trailing slash" do
      global_setting :maxmind_mirror_url, "https://b.www.example.com/mirror/"

      stub_request(:get, "https://b.www.example.com/mirror/GeoLite2-City.tar.gz").to_return(
        status: 200,
        body: "",
      )

      described_class.mmdb_download("GeoLite2-City")
    end

    it "should not throw an error and instead log the exception when database file fails to download" do
      fake_logger = FakeLogger.new
      Rails.logger.broadcast_to(fake_logger)

      global_setting :maxmind_license_key, "license_key"
      global_setting :maxmind_account_id, "account_id"

      stub_request(
        :get,
        "https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz",
      ).with(basic_auth: %w[account_id license_key]).to_return(status: 500, body: nil, headers: {})

      expect do described_class.mmdb_download("GeoLite2-City") end.not_to raise_error

      expect(fake_logger.warnings.length).to eq(1)

      expect(fake_logger.warnings.first).to include(
        "MaxMind database GeoLite2-City download failed. 500 Error",
      )
    ensure
      Rails.logger.stop_broadcasting_to(fake_logger)
    end
  end
end
