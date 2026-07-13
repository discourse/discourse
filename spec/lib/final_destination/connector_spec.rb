# frozen_string_literal: true

describe FinalDestination::Connector do
  describe "round-trip" do
    it "recovers the addresses it encoded" do
      token = described_class.encode("example.com", %w[1.2.3.4 2400:c800::1])

      expect(described_class.token?(token)).to eq(true)
      expect(described_class.addresses(token)).to eq(%w[1.2.3.4 2400:c800::1])
    end

    it "does not treat an ordinary hostname as a token" do
      expect(described_class.token?("example.com")).to eq(false)
    end
  end

  describe ".addresses_for_family" do
    let(:ips) { %w[1.2.3.4 5.6.7.8 2400:c800::1] }

    it "returns only IPv4 addresses for AF_INET" do
      expect(described_class.addresses_for_family(ips, Socket::AF_INET)).to contain_exactly(
        "1.2.3.4",
        "5.6.7.8",
      )
    end

    it "returns only IPv6 addresses for AF_INET6" do
      expect(described_class.addresses_for_family(ips, Socket::AF_INET6)).to contain_exactly(
        "2400:c800::1",
      )
    end

    it "returns every address when the family is unspecified" do
      expect(described_class.addresses_for_family(ips, nil)).to eq(ips)
    end
  end

  # The host is attacker-controlled (it comes from the URL) and rides in the token
  # only for readable errors. It must not be able to smuggle addresses past the
  # SSRF filter by embedding the token's delimiters.
  it "ignores delimiters smuggled into the host" do
    vetted = %w[1.2.3.4 2400:c800::1]

    ["evil|9.9.9.9", "evil|0.001|9.9.9.9", "a|b|c|d", "", "9.9.9.9,6.6.6.6"].each do |malicious_host|
      token = described_class.encode(malicious_host, vetted)

      expect(described_class.addresses(token)).to eq(vetted)
    end
  end
end
