# frozen_string_literal: true

require_relative "server_support"

describe DiscourseMcp::Server do
  include McpContentRestrictionsUnit3::ServerSupport

  it "[cr-u3] ListSiteSettings conceals personal-message URLs with only private_messages active and conceals public URLs" do
    message =
      Fabricate(
        :private_message_topic,
        id: 92_300_001,
        user: admin,
        title: "cru3 private legal destination",
      )
    Fabricate(:post, topic: message, user: admin)
    public_topic = Fabricate(:topic, user: admin)
    Fabricate(:post, topic: public_topic, user: admin)
    SiteSetting.tos_url = message.url
    baseline = rpc("discourse_list_site_settings", "names" => ["tos_url"])
    expect_usable(baseline)
    expect(payloads(baseline).first.fetch("site_settings").first.fetch("value")).to eq(message.url)
    McpContentRule.create!(rule_kind: "private_messages", config: {})
    expect(McpContentRule.pluck(:rule_kind)).to eq(["private_messages"])

    response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
    expect_usable(response)
    SiteSetting.tos_url = public_topic.url
    public_response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
    expect_usable(public_response)

    aggregate_failures do
      expect_absent(
        response,
        [message.relative_url, message.slug, message.id],
        "ListSiteSettings PM URL",
      )
      payloads(public_response).each do |payload|
        expect(payload.fetch("site_settings")).to include(
          a_hash_including(
            "setting" => "tos_url",
            "value" => nil,
            "default" => nil,
            "redacted" => true,
          ),
        )
      end
    end
  end
end
