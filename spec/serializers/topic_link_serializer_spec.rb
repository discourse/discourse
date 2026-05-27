# frozen_string_literal: true

RSpec.describe TopicLinkSerializer do
  it "correctly serializes the topic link" do
    post = Fabricate(:post, raw: "https://meta.discourse.org/")
    TopicLink.extract_from(post)
    serialized = described_class.new(post.topic_links.first, root: false).as_json

    expect(serialized[:domain]).to eq("meta.discourse.org")
    expect(serialized[:root_domain]).to eq("discourse.org")
  end

  describe "#url" do
    it "normalizes internal http:// URLs to https:// when force_https is enabled" do
      SiteSetting.force_https = true

      topic_link =
        Fabricate(:topic_link, url: "http://example.com/t/test-topic/123", internal: true)
      serialized = described_class.new(topic_link, root: false).as_json

      expect(serialized[:url]).to eq("https://example.com/t/test-topic/123")
    end

    it "does not modify external http:// URLs" do
      SiteSetting.force_https = true

      topic_link =
        Fabricate(
          :topic_link,
          url: "http://external-site.com/page",
          domain: "external-site.com",
          internal: false,
        )

      serialized = described_class.new(topic_link, root: false).as_json

      expect(serialized[:url]).to eq("http://external-site.com/page")
    end

    it "does not modify internal URLs when force_https is disabled" do
      SiteSetting.force_https = false

      topic_link =
        Fabricate(:topic_link, url: "http://example.com/t/test-topic/123", internal: true)
      serialized = described_class.new(topic_link, root: false).as_json

      expect(serialized[:url]).to eq("http://example.com/t/test-topic/123")
    end
  end
end
