# frozen_string_literal: true

require_relative "server_support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include McpContentRestrictionsUnit3::ServerSupport

  let(:denied_category) { Fabricate(:category, id: 112_850_100) }
  let(:denied_topic) { Fabricate(:topic, id: 112_850_101, category: denied_category) }

  before do
    Discourse.stubs(:current_hostname).returns("review-five-site.example")
    Discourse.stubs(:base_url).returns("https://review-five-site.example")
  end

  def review5_rows
    response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
    expect_usable(response)
    payloads(response).map { |payload| payload.fetch("site_settings").sole }
  end

  def review5_setting_rule(rule_kind)
    if rule_kind == "private_messages"
      McpContentRule.create!(rule_kind:, config: {})
    else
      forum_rule(denied_categories: [denied_category.id])
    end
  end

  {
    ideographic_full_stop: "review-five-site\u3002example",
    fullwidth_full_stop: "review-five-site\uFF0Eexample",
    halfwidth_ideographic_full_stop: "review-five-site\uFF61example",
    percent_encoded_ideographic_full_stop: "review-five-site%E3%80%82example",
    percent_encoded_fullwidth_full_stop: "review-five-site%EF%BC%8Eexample",
    percent_encoded_halfwidth_ideographic_full_stop: "review-five-site%EF%BD%A1example",
    percent_encoded_zero_width_space: "review-five-s%E2%80%8Bite.example",
    percent_encoded_soft_hyphen: "review-five-s%C2%ADite.example",
  }.each do |shape, link_host|
    %w[forum_content private_messages].each do |rule_kind|
      it "[cr-u3] conceals #{shape} host setting values and defaults under #{rule_kind}" do
        original_default = SiteSetting.defaults[:tos_url]
        url = "https://#{link_host}/t/secret/#{denied_topic.id}"
        external = "https://external.example/terms"
        %i[value default].each do |field|
          SiteSetting.defaults.set_regardless_of_locale(
            :tos_url,
            field == :default ? url : external,
          )
          SiteSetting.tos_url = field == :value ? url : external
          review5_rows.each do |row|
            expect(row).to include(
              "value" => field == :value ? url : external,
              "default" => field == :default ? url : external,
            )
          end
        end

        review5_setting_rule(rule_kind)
        aggregate_failures do
          %i[value default].each do |field|
            SiteSetting.defaults.set_regardless_of_locale(
              :tos_url,
              field == :default ? url : external,
            )
            SiteSetting.tos_url = field == :value ? url : external
            review5_rows.each do |row|
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

  %w[forum_content private_messages].each do |rule_kind|
    it "[cr-u3] keeps external ASCII host setting values and defaults under #{rule_kind}" do
      original_default = SiteSetting.defaults[:tos_url]
      value = "https://external.example/terms"
      default = "https://other-external.example/terms"
      SiteSetting.tos_url = value
      SiteSetting.defaults.set_regardless_of_locale(:tos_url, default)
      review5_setting_rule(rule_kind)
      review5_rows.each do |row|
        expect(row).to include("value" => value, "default" => default)
        expect(row["redacted"]).not_to eq(true)
      end
    ensure
      SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
