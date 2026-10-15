# frozen_string_literal: true

RSpec.describe "Imported topic embeds" do
  fab!(:embeddable_host) { Fabricate(:embeddable_host, host: "eviltrout.com") }

  let(:embed_url) { "http://eviltrout.com/'onmouseover='window.topicEmbedXssExecuted=true" }

  before do
    SiteSetting.content_security_policy = false
    SiteSetting.import_embed_unlisted = false
    Jobs.run_immediately!
    stub_request(:get, embed_url).to_return(
      status: 200,
      body: "<html><title>Embedded article</title><body><p>Article content</p></body></html>",
    )
  end

  it "does not execute JavaScript from an imported URL" do
    browser_page
      .goto("/embed/comments?#{{ embed_url: embed_url }.to_query}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_content).to PlaywrightMatchers.contain_text(
      browser_text_pattern(I18n.t("embed.loading")),
      useInnerText: true,
    )

    browser_page
      .goto(TopicEmbed.last.post.topic.url)
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    link =
      browser_root
        .locator("#post_1 .cooked a")
        .filter(visible: true)
        .filter(hasText: browser_text_pattern(embed_url))

    browser_page.evaluate("function(arguments) { window.topicEmbedXssExecuted = false }", arg: [])
    link.hover

    expect(
      browser_page.evaluate("function(arguments) { return window.topicEmbedXssExecuted }", arg: []),
    ).to eq(false)
    expect(link.get_attribute("onmouseover")).to be_nil
  end
end
