# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"

  before { SiteSetting.unique_posts_mins = 0 }

  {
    percent_encoded_capital_sharp_s: %w[xn--fa-hia.example fa%E1%BA%9E.example],
    unicode_sharp_s: ["xn--fa-hia.example", "fa\u00DF.example"],
    ipv4_short_dotted: %w[127.0.0.1 127.1],
    ipv4_decimal_integer: %w[127.0.0.1 2130706433],
    ipv4_hex_integer: %w[127.0.0.1 0x7f000001],
    ipv4_octal_dotted: %w[127.0.0.1 0177.0.0.1],
    ipv4_leading_zero_dotted: %w[127.0.0.1 127.000.000.001],
    ipv4_octal_integer: %w[127.0.0.1 017700000001],
    canonical_punycode: %w[xn--fa-hia.example xn--fa-hia.example],
    canonical_ipv4: %w[127.0.0.1 127.0.0.1],
  }.each do |shape, (site_host, link_host)|
    %i[forum pm].each do |rule|
      it "[cr-u4] refuses a labelled #{shape} internal host under #{rule} without persisting content" do
        Discourse.stubs(:current_hostname).returns(site_host)
        Discourse.stubs(:base_url).returns("https://#{site_host}")
        destination = Fabricate(:topic, id: 112_860_001, category: restricted_category)
        href = "https://#{link_host}/t/secret/#{destination.id}"
        raw = "Read [garden notes](#{href}) for seasonal observations."
        args = topic_arguments(raw:)
        isolated do
          data = expect_success(rpc("discourse_create_topic", args))
          written = Post.find(data.fetch("id"))
          anchor = Nokogiri::HTML5.fragment(written.cooked).at_css("a")
          expect(written.raw).to eq(raw)
          expect(anchor.text).to eq("garden notes")
          expect(anchor["href"]).to include("/t/secret/#{destination.id}")
          expected_href = link_host.ascii_only? ? href : href.sub(link_host, site_host)
          expect(anchor["href"]).to eq(expected_href)
        end

        activate!(rule)
        expected = reference_error
        before_state = content_state
        response = rpc("discourse_create_topic", args)
        aggregate_failures do
          expect_reference_refusal(response)
          expect(response).to eq(expected), "BROWSER HOST: labelled #{shape} link was accepted"
          expect(content_state).to eq(before_state),
          "BROWSER HOST ATOMICITY: labelled #{shape} link persisted content"
        end
      end
    end
  end

  {
    ipv6_with_userinfo: "https://visitor:password@[2001:db8::6]/page",
    ipv6_with_userinfo_and_port: "https://visitor:password@[2001:db8::6]:8443/page",
    ascii_host: "https://external.example/page",
    canonical_ipv4: "https://192.0.2.6/page",
  }.each do |shape, href|
    %i[forum pm].each do |rule|
      it "[cr-u4] accepts a labelled external #{shape} under #{rule}" do
        Discourse.stubs(:current_hostname).returns("127.0.0.1")
        Discourse.stubs(:base_url).returns("https://127.0.0.1")
        raw = "Read [garden notes](#{href}) for seasonal observations."
        args = topic_arguments(raw:)
        isolated do
          data = expect_success(rpc("discourse_create_topic", args))
          anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a")
          expect(anchor.text).to eq("garden notes")
          expect(anchor["href"]).to eq(href)
        end

        activate!(rule)
        data = expect_success(rpc("discourse_create_topic", args))
        written = Post.find(data.fetch("id"))
        anchor = Nokogiri::HTML5.fragment(written.cooked).at_css("a")
        expect(written.raw).to eq(raw)
        expect(anchor.text).to eq("garden notes")
        expect(anchor["href"]).to eq(href)
      end
    end
  end
end

describe DiscourseMcp::InternalHosts, ".include?" do
  {
    ipv6_literal: "https://[2001:db8::6]/page",
    ipv6_with_port: "https://[2001:db8::6]:8443/page",
  }.each do |shape, href|
    it "[cr-u4] classifies an external #{shape} as external with both URL parsers" do
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
