# frozen_string_literal: true

RSpec.describe DiscourseIpInfo do
  describe ".get" do
    let(:ip) { "81.2.69.142" }
    let(:expected_ip_info) do
      {
        city: "London",
        country: "United Kingdom",
        country_code: "GB",
        geoname_ids: [6_255_148, 2_635_167, 2_643_743, 6_269_131],
        location: "London, England, United Kingdom",
        region: "England",
        latitude: 51.5142,
        longitude: -0.0931,
      }
    end

    before { described_class.open_db(Rails.root.join("spec/fixtures/mmdb").to_s) }

    it "returns IP info without hostname when reverse DNS is interrupted" do
      Resolv::DNS.any_instance.stubs(:getname).with(ip).raises(Timeout::Error)

      result = described_class.get(ip, resolve_hostname: true)

      expect(result).to eq(expected_ip_info)
    end

    it "sets a timeout for reverse DNS" do
      resolver = Resolv::DNS.new
      resolver
        .expects(:timeouts=)
        .with { |timeouts| Array(timeouts).present? && Array(timeouts).sum <= 5 }
      resolver.stubs(:getname).with(ip).raises(Resolv::ResolvError)

      Resolv::DNS.stubs(:new).returns(resolver)

      result = described_class.get(ip, resolve_hostname: true)

      expect(result).to eq(expected_ip_info)
    end
  end

  describe ".asn_organization" do
    let(:ip) { "192.0.2.1" }
    let(:database) { mock }
    let(:result) { mock }

    before do
      instance = described_class.instance
      @original_asn_database = instance.instance_variable_get(:@asn_mmdb)
      @original_asn_cache = instance.instance_variable_get(:@asn_organization_cache)
      instance.instance_variable_set(:@asn_mmdb, database)
      instance.instance_variable_set(:@asn_organization_cache, LruRedux::ThreadSafeCache.new(2000))
    end

    after do
      instance = described_class.instance
      instance.instance_variable_set(:@asn_mmdb, @original_asn_database)
      instance.instance_variable_set(:@asn_organization_cache, @original_asn_cache)
    end

    it "returns the organization when the current ASN matches the stored ASN" do
      database.expects(:lookup).with(ip).returns(result)
      result.stubs(:found?).returns(true)
      result.stubs(:to_hash).returns(
        "autonomous_system_number" => 64_500,
        "autonomous_system_organization" => "Example Network",
      )

      organization = described_class.asn_organization(ip: ip, expected_asn: 64_500)

      expect(organization).to eq("Example Network")
    end

    it "does not include the IP address in a lookup error" do
      fake_logger = FakeLogger.new
      Rails.logger.broadcast_to(fake_logger)
      database.stubs(:lookup).with(ip).raises(StandardError, "lookup failed")

      organization = described_class.asn_organization(ip: ip, expected_asn: 64_500)

      expect(organization).to be_nil
      expect(fake_logger.warnings.join).not_to include(ip)
    ensure
      Rails.logger.stop_broadcasting_to(fake_logger)
    end
  end

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
