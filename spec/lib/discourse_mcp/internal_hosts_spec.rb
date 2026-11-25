# frozen_string_literal: true

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::InternalHosts, ".include?" do
  {
    ipv6_literal: "https://[2001:db8::6]/page",
    ipv6_with_port: "https://[2001:db8::6]:8443/page",
  }.each do |shape, href|
    it "classifies an external #{shape} as external with both URL parsers" do
      Discourse.stubs(:current_hostname).returns("127.0.0.1")
      Discourse.stubs(:base_url).returns("https://127.0.0.1")

      aggregate_failures do
        [URI.parse(href), Addressable::URI.parse(href)].each do |uri|
          expect(described_class.include?(uri)).to eq(false),
          "EXTERNAL IPV6 CLASSIFIED INTERNAL by #{uri.class}: #{href}"
        end
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
