# frozen_string_literal: true

RSpec.describe DiscourseIpInfo do
  describe ".mmdb_download" do
    it "should download the MaxMind databases from MaxMind's download permalinks when `maxmind_license_key` and `maxmind_account_id` global setting has been set" do
      global_setting :maxmind_license_key, "license_key"
      global_setting :maxmind_account_id, "account_id"

      stub_request(
        :get,
        "https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz",
      ).with(basic_auth: %w[account_id license_key]).to_return(status: 200, body: "", headers: {})

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
  end
end
