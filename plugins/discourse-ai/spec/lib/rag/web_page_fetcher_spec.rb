# frozen_string_literal: true

RSpec.describe DiscourseAi::Rag::WebPageFetcher do
  before { enable_current_plugin }

  it "extracts readable page content and response validators" do
    url = "https://example.com/docs"
    navigation = "Home Documentation Pricing"
    article_heading = "Installation guide"
    article_paragraphs = [
      "This guide explains how to install the package safely and configure it for production environments.",
      "First download the package, verify its checksum, and run the installer using the documented command.",
      "After installation, edit the configuration file and restart the service to apply all settings.",
    ]
    footer = "Privacy Terms Copyright"
    stub_request(:get, url).to_return(
      status: 200,
      headers: {
        "Content-Type" => "text/html; charset=utf-8",
        "ETag" => '"revision-2"',
        "Last-Modified" => "Wed, 19 Aug 2026 16:00:00 GMT",
      },
      body: <<~HTML,
        <html>
          <body>
            <nav>#{navigation}</nav>
            <div class="article-copy">
              <h1>#{article_heading}</h1>
              #{article_paragraphs.map { |paragraph| "<p>#{paragraph}</p>" }.join}
            </div>
            <footer>#{footer}</footer>
            <script>ignoreMe()</script>
          </body>
        </html>
      HTML
    )

    result = described_class.fetch(url: url)

    expect(result).to include(
      not_modified: false,
      url: url,
      text: ([article_heading] + article_paragraphs).join(" "),
      etag: '"revision-2"',
      last_modified: "Wed, 19 Aug 2026 16:00:00 GMT",
    )
  end

  it "uses conditional request headers and handles an unchanged page" do
    url = "https://example.com/docs"
    stub_request(:get, url).to_return(status: 304)

    result =
      described_class.fetch(
        url: url,
        etag: '"revision-2"',
        last_modified: "Wed, 19 Aug 2026 16:00:00 GMT",
      )

    expect(result).to eq(not_modified: true)
    expect(
      a_request(:get, url).with(
        headers: {
          "If-None-Match" => '"revision-2"',
          "If-Modified-Since" => "Wed, 19 Aug 2026 16:00:00 GMT",
        },
      ),
    ).to have_been_made.once
  end

  it "requests and preserves Markdown content" do
    url = "https://example.com/docs.md"
    markdown = <<~MARKDOWN
      # Installation

      Run `bundle install`, then:

      - Configure the service
      - Restart the process
    MARKDOWN
    stub_request(:get, url).to_return(
      status: 200,
      headers: {
        "Content-Type" => "text/markdown; charset=utf-8",
      },
      body: markdown,
    )

    result = described_class.fetch(url: url)

    expect(result).to include(not_modified: false, url: url, text: markdown)
    expect(
      a_request(:get, url).with(headers: { "Accept" => "text/markdown, */*" }),
    ).to have_been_made.once
  end

  it "follows redirects without an additional discovery request" do
    original_url = "https://example.com/docs"
    redirected_url = "https://docs.example.com/guide"
    stub_request(:get, original_url).to_return(
      status: 302,
      headers: {
        "Location" => redirected_url,
      },
    )
    stub_request(:get, redirected_url).to_return(
      status: 200,
      headers: {
        "Content-Type" => "text/plain",
      },
      body: "The guide",
    )

    result = described_class.fetch(url: original_url)

    expect(result).to include(url: redirected_url, text: "The guide")
    expect(a_request(:get, original_url)).to have_been_made.once
    expect(a_request(:get, redirected_url)).to have_been_made.once
  end

  it "normalizes transport timeouts into fetch errors" do
    url = "https://example.com/docs"
    stub_request(:get, url).to_timeout

    expect { described_class.fetch(url: url) }.to raise_error(
      DiscourseAi::Rag::WebPageFetcher::FetchError,
    )
  end
end
