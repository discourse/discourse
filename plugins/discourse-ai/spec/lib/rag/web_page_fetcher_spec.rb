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
    stub_request(:get, url).to_return({ status: 200 }, { status: 304 })

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
    ).to have_been_made
  end
end
