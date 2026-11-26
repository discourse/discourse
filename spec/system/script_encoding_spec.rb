# frozen_string_literal: true

describe "script encoding" do
  let(:cdn_path) { "/__system_test_cdn" }
  let(:cdn_url) { "#{Discourse.base_url_no_prefix}#{cdn_path}" }
  let(:js_cdn_requests) { [] }

  before do
    requests = js_cdn_requests
    prefix = cdn_path
    base_path = Discourse.base_path

    Capybara.app.intercept do |env, app|
      path = env.fetch("PATH_INFO")
      if path.start_with?("#{prefix}/")
        requests << path if path.end_with?(".js")

        # We don't actually have assets/br/ files or a CDN, so invisibly
        # rewrite the request to the regular assets
        asset_path = path.delete_prefix(prefix).delete_prefix(base_path)
        asset_path = asset_path.sub(%r{\A/assets/br/}, "/assets/js/")
        env = env.merge("PATH_INFO" => "#{base_path}#{asset_path}")
      elsif path == "#{base_path}/latest"
        encodings = env["HTTP_ACCEPT_ENCODING"].to_s.split(/,\s*/)
        env = env.merge("HTTP_ACCEPT_ENCODING" => (encodings | ["br"]).join(", "))
      end

      app.call(env)
    end
  end

  context "without s3 assets" do
    before { set_cdn_url cdn_url }

    it "loads JS chunks with the .js extension" do
      user = Fabricate(:admin)
      sign_in user

      visit "/latest"

      expect(js_cdn_requests.length).to be > 1
      expect(js_cdn_requests.any? { |r| r.match?(%r{/br/.+\.js\Z}) }).to eq(false)

      js_cdn_requests.clear

      # Use the composer to trigger an async chunk load
      find("#create-topic").click
      find(".d-editor-input").fill_in(with: "This is a test")
      expect(page).to have_css(".d-editor-preview", text: "This is a test")

      expect(js_cdn_requests.length).to be > 1
      expect(js_cdn_requests.any? { |r| r.match?(%r{/br/.+\.js\Z}) }).to eq(false)
    end
  end

  context "with s3 assets" do
    before do
      global_setting :s3_bucket, "test_bucket"
      global_setting :s3_region, "ap-australia"
      global_setting :s3_access_key_id, "123"
      global_setting :s3_secret_access_key, "123"
      global_setting :s3_cdn_url, cdn_url
    end

    it "loads JS chunks with the /br/ path" do
      user = Fabricate(:admin)
      sign_in user

      visit "/latest"

      expect(js_cdn_requests.length).to be > 1
      expect(js_cdn_requests.all? { |r| r.match?(%r{/br/.+\.js\Z}) }).to eq(true)

      js_cdn_requests.clear

      # Use the composer to trigger an async chunk load
      find("#create-topic").click
      find(".d-editor-input").fill_in(with: "This is a test")
      expect(page).to have_css(".d-editor-preview", text: "This is a test")

      expect(js_cdn_requests.length).to be > 1
      expect(js_cdn_requests.all? { |r| r.match?(%r{/br/.+\.js\Z}) }).to eq(true)
    end
  end
end
