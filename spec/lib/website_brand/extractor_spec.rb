# frozen_string_literal: true

RSpec.describe WebsiteBrand::Extractor do
  subject(:profile) { described_class.new(url).call }

  let(:url) { "https://brand.example.com/" }

  before { stub_request(:get, /.*/).to_return(status: 404) }

  def stub_file(path, body, content_type: "text/html")
    stub_request(:get, "https://brand.example.com#{path}").to_return(
      body:,
      headers: {
        "Content-Type" => content_type,
      },
    )
  end

  it "reads the brand color from the signals a page sets on purpose" do
    stub_file("/", <<~HTML)
      <html>
        <head>
          <meta name="theme-color" content="#635bff">
          <link rel="manifest" href="/site.webmanifest">
          <link rel="stylesheet" href="/site.css">
        </head>
        <body><a class="btn btn-primary" href="/signup">Sign up</a></body>
      </html>
    HTML
    stub_file(
      "/site.webmanifest",
      { theme_color: "#635BFF", background_color: "#ffffff" }.to_json,
      content_type: "application/manifest+json",
    )
    stub_file("/site.css", <<~CSS, content_type: "text/css")
      :root { --brand-primary: #635bff; --text-primary: #1a1a1a; }
      a { color: var(--brand-primary); }
      .btn-primary { background-color: #635bff; }
      .footer { background: #f6f9fc; color: #425466; }
    CSS

    expect(profile).to have_attributes(
      url:,
      brand: "635bff",
      confidence: :high,
      background: "ffffff",
      dark: false,
    )
  end

  it "finds an accent color and a header that stands out from the page" do
    stub_file("/", <<~HTML)
      <html>
        <head>
          <meta name="theme-color" content="#0066cc">
          <style>
            header { background-color: #0a2540; }
            a { color: #0066cc; }
            .button { background: #e8590c; }
          </style>
        </head>
        <body>
          <header><nav>Brand</nav></header>
          <button class="button">Join</button>
        </body>
      </html>
    HTML

    expect(profile).to have_attributes(brand: "0066cc", accent: "e8590c", header: "0a2540")
  end

  it "only counts utility classes on the buttons that use them" do
    stub_file("/", <<~HTML)
      <html>
        <head>
          <style>
            .bg-indigo-600 { background-color: #4f46e5; }
            .bg-pink-500 { background-color: #ec4899; }
          </style>
        </head>
        <body>
          <button class="rounded bg-indigo-600 px-4">Get started</button>
          <div class="bg-pink-500">Banner</div>
        </body>
      </html>
    HTML

    expect(profile.brand).to eq("4f46e5")
  end

  it "falls back to the colors of the site's icon" do
    stub_file("/", '<link rel="icon" type="image/svg+xml" href="/icon.svg">')
    stub_file(
      "/icon.svg",
      '<svg xmlns="http://www.w3.org/2000/svg"><circle fill="#1ed760" r="5"/></svg>',
      content_type: "image/svg+xml",
    )

    expect(profile).to have_attributes(brand: "1ed760", confidence: :medium)
  end

  it "notices dark sites and matches their fonts" do
    stub_file("/", <<~HTML)
      <html>
        <head>
          <style>
            body { background: #111111; font-family: var(--body-font); }
            :root { --body-font: "Inter Variable", sans-serif; }
            h1 { font-family: Georgia, serif; }
          </style>
        </head>
      </html>
    HTML

    expect(profile).to have_attributes(
      background: "111111",
      dark: true,
      body_font: WebsiteBrand::Fonts::Match.new(key: "inter", exact: true),
      heading_font: WebsiteBrand::Fonts::Match.new(key: "merriweather", exact: false),
    )
  end

  it "takes the body font from Google Fonts when the page's CSS doesn't name one" do
    stub_file(
      "/",
      '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Lora:wght@400;700&family=Inter&display=swap">',
    )

    expect(profile.body_font).to eq(WebsiteBrand::Fonts::Match.new(key: "lora", exact: true))
  end

  it "ignores interaction states, dark mode styles and print styles" do
    stub_file("/", <<~HTML)
      <html>
        <head>
          <meta name="theme-color" content="#0066cc">
          <meta name="theme-color" media="(prefers-color-scheme: dark)" content="#e8590c">
          <link rel="stylesheet" media="print" href="/print.css">
          <style>
            a:hover { color: #e8590c; }
            @media (prefers-color-scheme: dark) { a { color: #e8590c; } }
            .dark .btn-primary { background: #e8590c; }
          </style>
        </head>
      </html>
    HTML

    expect(profile.candidates).to eq(["0066cc"])
    expect(a_request(:get, "https://brand.example.com/print.css")).not_to have_been_made
  end

  it "follows one meta refresh" do
    stub_file("/", '<meta http-equiv="Refresh" content="0; url=/en/">')
    stub_file("/en/", <<~HTML)
      <meta http-equiv="refresh" content="0; url=/en/home">
      <meta name="theme-color" content="#e8590c">
    HTML

    expect(profile).to have_attributes(url: "https://brand.example.com/en/", brand: "e8590c")
    expect(a_request(:get, "https://brand.example.com/en/home")).not_to have_been_made
  end

  it "reports when a page has no brand color" do
    stub_file("/", <<~HTML)
      <style>body { color: #222222; } a { color: #555555; } .card { background: #f5f5f5; }</style>
    HTML

    expect(profile).to have_attributes(brand: nil, accent: nil, candidates: [], confidence: :low)
  end

  it "returns nil when the page can't be read" do
    stub_request(:get, url).to_return(status: 500)

    expect(profile).to be_nil
  end
end
