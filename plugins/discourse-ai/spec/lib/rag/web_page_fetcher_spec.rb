# frozen_string_literal: true

RSpec.describe DiscourseAi::Rag::WebPageFetcher do
  before { enable_current_plugin }

  it "extracts readable page content and response validators" do
    url = "https://example.com/docs"
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
            <nav>Navigation</nav>
            <main><h1>Installation</h1><p>Install the package.</p></main>
            <script>ignoreMe()</script>
          </body>
        </html>
      HTML
    )

    result = described_class.fetch(url: url)

    expect(result).to include(
      not_modified: false,
      url: url,
      text: "Installation Install the package.",
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
