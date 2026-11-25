# frozen_string_literal: true

require_relative "server_support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include McpContentRestrictionsUnit3::ServerSupport

  let(:denied_category) { Fabricate(:category, id: 112_840_100) }
  let(:denied_topic) { Fabricate(:topic, id: 112_840_101, category: denied_category) }

  def review4_rows(names = ["tos_url"])
    response = rpc("discourse_list_site_settings", "names" => names)
    expect_usable(response)
    payloads(response).map { |payload| payload.fetch("site_settings") }
  end

  def review4_setting_rule(rule_kind)
    if rule_kind == "private_messages"
      McpContentRule.create!(rule_kind:, config: {})
    else
      forum_rule(denied_categories: [denied_category.id])
    end
  end

  def review4_conceals(url, rule_kind)
    original_default = SiteSetting.defaults[:tos_url]
    external = "https://external.example/terms"
    %i[value default].each do |field|
      SiteSetting.defaults.set_regardless_of_locale(:tos_url, field == :default ? url : external)
      SiteSetting.tos_url = field == :value ? url : external
      review4_rows.each do |rows|
        expect(rows.sole).to include(
          "value" => field == :value ? url : external,
          "default" => field == :default ? url : external,
        )
      end
    end
    review4_setting_rule(rule_kind)
    aggregate_failures do
      %i[value default].each do |field|
        SiteSetting.defaults.set_regardless_of_locale(:tos_url, field == :default ? url : external)
        SiteSetting.tos_url = field == :value ? url : external
        review4_rows.each do |rows|
          expect(rows.sole).to include("value" => nil, "default" => nil, "redacted" => true),
          "BROWSER LOCAL URL RETAINED in #{field}: #{url.inspect}"
        end
      end
    end
  ensure
    SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
  end

  %w[forum_content private_messages].each do |rule_kind|
    %i[percent_encoded trailing_dot uppercase unicode_site punycode_site].each do |shape|
      it "[cr-u3] conceals #{shape} host setting values and defaults under #{rule_kind}" do
        host =
          case shape
          when :unicode_site
            "bücher.example"
          when :punycode_site
            "xn--bcher-kva.example"
          else
            "review-four-site.example"
          end
        Discourse.stubs(:current_hostname).returns(
          shape == :unicode_site ? "review-four-site.example" : host,
        )
        Discourse.stubs(:base_url).returns("https://#{host}")
        link_host =
          case shape
          when :percent_encoded
            "review-four-s%69te.example"
          when :trailing_dot
            "#{host}."
          when :uppercase
            host.upcase
          when :unicode_site
            "xn--bcher-kva.example"
          else
            "bücher.example"
          end
        review4_conceals("https://#{link_host}/t/secret/#{denied_topic.id}", rule_kind)
      end
    end

    %i[
      bare_relative
      special_scheme_slash
      special_scheme_relative
      backslash_relative
      backslash_absolute
      backslash_network
      backslash_short_host
    ].each do |shape|
      it "[cr-u3] conceals #{shape} URL setting values and defaults under #{rule_kind}" do
        host = shape == :backslash_short_host ? "t" : "review-four-site.example"
        Discourse.stubs(:current_hostname).returns(host)
        Discourse.stubs(:base_url).returns("https://#{host}")
        path = "t/secret/#{denied_topic.id}"
        url =
          case shape
          when :bare_relative
            path
          when :special_scheme_slash
            "https:/#{path}"
          when :special_scheme_relative
            "https:#{path}"
          when :backslash_relative
            "\\#{path.tr("/", "\\")}"
          when :backslash_absolute
            "https:\\\\#{host}\\#{path.tr("/", "\\")}"
          when :backslash_network
            "\\\\#{host}\\#{path.tr("/", "\\")}"
          else
            "\\\\t\\\\secret"
          end
        review4_conceals(url, rule_kind)
      end
    end

    it "[cr-u3] keeps external absolute URLs and plain non-URL settings under #{rule_kind}" do
      original_default = SiteSetting.defaults[:tos_url]
      value = "https://external.example/terms"
      default = "https://other-external.example/terms"
      SiteSetting.tos_url = value
      SiteSetting.defaults.set_regardless_of_locale(:tos_url, default)
      SiteSetting.title = "Seasonal garden forum"
      review4_setting_rule(rule_kind)
      review4_rows(%w[tos_url title]).each do |rows|
        settings = rows.index_by { |row| row.fetch("setting") }
        expect(settings.fetch("tos_url")).to include("value" => value, "default" => default)
        expect(settings.fetch("title")).to include(
          "value" => SiteSetting.title,
          "default" => SiteSetting.defaults[:title],
        )
        settings.each_value { |row| expect(row["redacted"]).not_to eq(true) }
      end
    ensure
      SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
