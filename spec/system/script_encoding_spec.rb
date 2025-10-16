# frozen_string_literal: true

describe "script encoding" do
  let(:js_cdn_requests) { [] }

  before { stub_and_log_cdn_requests }

  def stub_and_log_cdn_requests
    page.driver.with_playwright_page do |page|
      page.route(
        "http://cdn.example.com/**/*",
        ->(route, request) do
          js_cdn_requests << request.url if request.url.end_with?(".js")
          origin_uri = URI(request.frame.url)
          request_uri = URI(request.url)

          # We don't actually have .br.js files or a CDN, so invisibly
          # rewrite the request to the regular assets
          mocked_result =
            URI::HTTP.build(
              scheme: origin_uri.scheme,
              host: origin_uri.host,
              port: origin_uri.port,
              path: request_uri.path.sub(".br.js", ".js"),
            )
          route.continue(url: mocked_result.to_s)
        end,
      )
    end
  end

  context "without s3 assets" do
    before { set_cdn_url "http://cdn.example.com" }

    it "loads JS chunks with the .js extension" do
      user = Fabricate(:admin)
      sign_in user

      visit "/latest"

      expect(page).to have_css("#site-logo")

      expect(js_cdn_requests.length).to be > 2
      expect(js_cdn_requests.any? { |r| r.end_with?(".br.js") }).to eq(false)
      expect(js_cdn_requests.all? { |r| r.end_with?(".js") }).to eq(true)

      js_cdn_requests.clear

      # Use the composer to trigger an async chunk load
      find("#create-topic").click
      find(".d-editor-input").fill_in(with: "This is a test")
      expect(page).to have_css(".d-editor-preview", text: "This is a test")

      expect(js_cdn_requests.length).to be > 2
      expect(js_cdn_requests.any? { |r| r.end_with?(".br.js") }).to eq(false)
      expect(js_cdn_requests.all? { |r| r.end_with?(".js") }).to eq(true)
    end
  end

  context "with s3 assets" do
    before do
      global_setting :s3_bucket, "test_bucket"
      global_setting :s3_region, "ap-australia"
      global_setting :s3_access_key_id, "123"
      global_setting :s3_secret_access_key, "123"
      global_setting :s3_cdn_url, "http://cdn.example.com"
    end

    it "loads JS chunks with the .br.js extension" do
      user = Fabricate(:admin)
      sign_in user

      visit "/latest"

      expect(page).to have_css("#site-logo")

      expect(js_cdn_requests.length).to be > 2
      expect(js_cdn_requests.all? { |r| r.end_with?(".br.js") }).to eq(true)

      js_cdn_requests.clear

      # Use the composer to trigger an async chunk load
      find("#create-topic").click
      find(".d-editor-input").fill_in(with: "This is a test")
      expect(page).to have_css(".d-editor-preview", text: "This is a test")

      expect(js_cdn_requests.length).to be > 2
      expect(js_cdn_requests.all? { |r| r.end_with?(".br.js") }).to eq(true)
    end
  end
end
