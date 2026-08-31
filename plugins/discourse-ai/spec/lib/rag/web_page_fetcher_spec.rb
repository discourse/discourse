# frozen_string_literal: true

RSpec.describe DiscourseAi::Rag::WebPageFetcher do
  before { enable_current_plugin }

  it "extracts readable page content and response validators" do
    url = "https://example.com/docs"
    navigation = "Home Documentation Pricing"
    article_heading = "Installation"
    article_paragraph = "Install the package."
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
            <main>
              <h1>#{article_heading}</h1>
              <p>#{article_paragraph}</p>
            </main>
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
      text: "#{article_heading} #{article_paragraph}",
      etag: '"revision-2"',
      last_modified: "Wed, 19 Aug 2026 16:00:00 GMT",
    )
  end

  it "converts rectangular HTML table rows to Markdown" do
    url = "https://example.com/pricing"
    stub_request(:get, url).to_return(
      status: 200,
      headers: {
        "Content-Type" => "text/html",
      },
      body: <<~HTML,
        <main>
          <h1>Compare plans &amp; features</h1>
          <table>
            <thead>
              <tr><th colspan="5">Community</th></tr>
              <tr><th>Feature</th><th>Free</th><th>Pro</th><th>Business</th><th>Enterprise</th></tr>
            </thead>
            <tbody>
              <tr><td></td><td colspan="4">Staff seats</td></tr>
              <tr><td>Staff seats</td><td>2</td><td>5</td><td>15</td><td>Unlimited</td></tr>
              <tr><td></td><td colspan="4">Custom groups</td></tr>
              <tr>
                <td>Custom groups</td>
                <td></td>
                <td><i aria-label="Included"></i></td>
                <td><i aria-label="Included"></i></td>
                <td><i aria-label="Included"></i></td>
              </tr>
            </tbody>
          </table>
        </main>
      HTML
    )

    result = described_class.fetch(url: url)

    expect(result[:text]).to eq(<<~MARKDOWN.strip)
      Compare plans & features

      | Feature | Free | Pro | Business | Enterprise |
      | --- | --- | --- | --- | --- |
      | Staff seats | 2 | 5 | 15 | Unlimited |
      | Custom groups |  | Included | Included | Included |
    MARKDOWN
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
