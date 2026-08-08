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
    visit("/embed/comments?#{{ embed_url: embed_url }.to_query}")
    expect(page).to have_content(I18n.t("embed.loading"))

    visit(TopicEmbed.last.post.topic.url)
    link = find("#post_1 .cooked a", text: embed_url)

    page.execute_script("window.topicEmbedXssExecuted = false")
    link.hover

    expect(page.evaluate_script("window.topicEmbedXssExecuted")).to eq(false)
    expect(link["onmouseover"]).to be_nil
  end
end
