# frozen_string_literal: true

require_relative "server_support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include McpContentRestrictionsUnit3::ServerSupport

  let(:denied_category) { Fabricate(:category, id: 112_860_100) }
  let(:denied_topic) { Fabricate(:topic, id: 112_860_101, category: denied_category) }

  def review6_rows
    response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
    expect_usable(response)
    payloads(response).map { |payload| payload.fetch("site_settings").sole }
  end

  def review6_setting_rule(rule_kind)
    if rule_kind == "private_messages"
      McpContentRule.create!(rule_kind:, config: {})
    else
      forum_rule(denied_categories: [denied_category.id])
    end
  end

  {
    percent_encoded_capital_sharp_s: %w[xn--fa-hia.example fa%E1%BA%9E.example],
    unicode_capital_sharp_s: ["xn--fa-hia.example", "fa\u1E9E.example"],
    ipv4_short_dotted: %w[127.0.0.1 127.1],
    ipv4_decimal_integer: %w[127.0.0.1 2130706433],
    ipv4_hex_integer: %w[127.0.0.1 0x7f000001],
    ipv4_octal_dotted: %w[127.0.0.1 0177.0.0.1],
    ipv4_leading_zero_dotted: %w[127.0.0.1 127.000.000.001],
    ipv4_octal_integer: %w[127.0.0.1 017700000001],
    canonical_punycode: %w[xn--fa-hia.example xn--fa-hia.example],
    canonical_ipv4: %w[127.0.0.1 127.0.0.1],
  }.each do |shape, (site_host, link_host)|
    %w[forum_content private_messages].each do |rule_kind|
      it "[cr-u3] conceals #{shape} host setting values and defaults under #{rule_kind}" do
        Discourse.stubs(:current_hostname).returns(site_host)
        Discourse.stubs(:base_url).returns("https://#{site_host}")
        original_default = SiteSetting.defaults[:tos_url]
        url = "https://#{link_host}/t/secret/#{denied_topic.id}"
        external = "https://external.example/terms"
        %i[value default].each do |field|
          SiteSetting.defaults.set_regardless_of_locale(
            :tos_url,
            field == :default ? url : external,
          )
          SiteSetting.tos_url = field == :value ? url : external
          review6_rows.each do |row|
            expect(row).to include(
              "value" => field == :value ? url : external,
              "default" => field == :default ? url : external,
            )
          end
        end

        review6_setting_rule(rule_kind)
        aggregate_failures do
          %i[value default].each do |field|
            SiteSetting.defaults.set_regardless_of_locale(
              :tos_url,
              field == :default ? url : external,
            )
            SiteSetting.tos_url = field == :value ? url : external
            review6_rows.each do |row|
              expect(row).to include("value" => nil, "default" => nil, "redacted" => true),
              "BROWSER HOST SETTING RETAINED in #{field}: #{url.inspect}"
            end
          end
        end
      ensure
        SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
      end
    end
  end

  {
    ipv6_literal: "https://[2001:db8::6]/page",
    ipv6_with_port: "https://[2001:db8::6]:8443/page",
    ipv6_with_userinfo: "https://visitor:password@[2001:db8::6]/page",
    ipv6_with_userinfo_and_port: "https://visitor:password@[2001:db8::6]:8443/page",
    ascii_host: "https://external.example/page",
    canonical_ipv4: "https://192.0.2.6/page",
  }.each do |shape, url|
    %w[forum_content private_messages].each do |rule_kind|
      it "[cr-u3] keeps external #{shape} setting values and defaults under #{rule_kind}" do
        Discourse.stubs(:current_hostname).returns("127.0.0.1")
        Discourse.stubs(:base_url).returns("https://127.0.0.1")
        original_default = SiteSetting.defaults[:tos_url]
        external = "https://other-external.example/terms"
        %i[value default].each do |field|
          SiteSetting.defaults.set_regardless_of_locale(
            :tos_url,
            field == :default ? url : external,
          )
          SiteSetting.tos_url = field == :value ? url : external
          review6_rows.each do |row|
            expect(row).to include(
              "value" => field == :value ? url : external,
              "default" => field == :default ? url : external,
            )
          end
        end

        review6_setting_rule(rule_kind)
        aggregate_failures do
          %i[value default].each do |field|
            SiteSetting.defaults.set_regardless_of_locale(
              :tos_url,
              field == :default ? url : external,
            )
            SiteSetting.tos_url = field == :value ? url : external
            review6_rows.each do |row|
              expect(row).to include(
                "value" => field == :value ? url : external,
                "default" => field == :default ? url : external,
              ),
              "EXTERNAL HOST SETTING REDACTED in #{field}: #{url.inspect}"
              expect(row["redacted"]).not_to eq(true)
            end
          end
        end
      ensure
        SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
