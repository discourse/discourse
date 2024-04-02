# frozen_string_literal: true

RSpec.describe DiscourseIpInfo do
  describe ".mmdb_download" do
    it "should download the MaxMind databases from the right URL when `maxmind_mirror_url` global setting has been configured" do
      global_setting :maxmind_mirror_url, "https://example.com/mirror/"

      stub_request(:get, "https://example.com/mirror/GeoLite2-City.tar.gz").to_return(
        status: 200,
        body: "",
      )

      described_class.mmdb_download("GeoLite2-City")
    end
  end
end
