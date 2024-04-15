# frozen_string_literal: true
RSpec.describe ThemeJavascriptsController do
  include ActiveSupport::Testing::TimeHelpers

  before { ThemeJavascriptCompiler.disable_terser! }
  after { ThemeJavascriptCompiler.enable_terser! }

  def clear_disk_cache
    if Dir.exist?(ThemeJavascriptsController::DISK_CACHE_PATH)
      `rm -rf #{ThemeJavascriptsController::DISK_CACHE_PATH}`
    end
  end

  let!(:theme) { Fabricate(:theme) }
  let(:theme_field) do
    ThemeField.create!(theme: theme, target_id: 0, name: "header", value: "<a>html</a>")
  end
  let(:javascript_cache) do
    JavascriptCache.create!(content: 'console.log("hello");', theme_field: theme_field)
  end
  before { clear_disk_cache }
  after { clear_disk_cache }

  describe "#show" do
    def update_digest_and_get(digest)
      # actually set digest to make sure 404 is raised by router
      javascript_cache.update(digest: digest)

      get "/theme-javascripts/#{digest}.js"
    end

    it "only accepts 40-char hexadecimal digest name" do
      update_digest_and_get("0123456789abcdefabcd0123456789abcdefabcd")
      expect(response.status).to eq(200)

      update_digest_and_get("0123456789abcdefabcd0123456789abcdefabc")
      expect(response.status).to eq(404)

      update_digest_and_get("gggggggggggggggggggggggggggggggggggggggg")
      expect(response.status).to eq(404)

      update_digest_and_get("0123456789abcdefabc_0123456789abcdefabcd")
      expect(response.status).to eq(404)

      update_digest_and_get("0123456789abcdefabc-0123456789abcdefabcd")
      expect(response.status).to eq(404)

      update_digest_and_get("../../Gemfile")
      expect(response.status).to eq(404)
    end

    it "considers the database record as the source of truth" do
      clear_disk_cache

      get "/theme-javascripts/#{javascript_cache.digest}.js"
      expect(response.status).to eq(200)
      expect(response.body).to eq(javascript_cache.content)
      expect(response.headers["Content-Length"]).to eq(javascript_cache.content.bytesize.to_s)

      javascript_cache.destroy!

      get "/theme-javascripts/#{javascript_cache.digest}.js"
      expect(response.status).to eq(404)
    end

    it "adds sourceMappingUrl if there is a source map" do
      digest = SecureRandom.hex(20)
      javascript_cache.update(digest: digest)
      get "/theme-javascripts/#{digest}.js"
      expect(response.status).to eq(200)
      expect(response.body).to eq('console.log("hello");')

      digest = SecureRandom.hex(20)
      javascript_cache.update(digest: digest, source_map: "{fakeSourceMap: true}")
      get "/theme-javascripts/#{digest}.js"
      expect(response.status).to eq(200)
      expect(response.body).to eq <<~JS
        console.log("hello");
        //# sourceMappingURL=#{digest}.map?__ws=test.localhost
      JS
    end

    it "ignores Accept header and does not return Vary header" do
      js_cache_url = "/theme-javascripts/#{javascript_cache.digest}.js"

      get js_cache_url
      expect(response.status).to eq(200)
      expect(response.headers["Content-Type"]).to eq("text/javascript")
      expect(response.headers["Vary"]).to eq(nil)

      get js_cache_url, headers: { "Accept" => "text/html" }
      expect(response.status).to eq(200)
      expect(response.headers["Content-Type"]).to eq("text/javascript")
      expect(response.headers["Vary"]).to eq(nil)

      get js_cache_url, headers: { "Accept" => "invalidcontenttype" }
      expect(response.status).to eq(200)
      expect(response.headers["Content-Type"]).to eq("text/javascript")
      expect(response.headers["Vary"]).to eq(nil)
    end
  end

  describe "#show_map" do
    it "returns a source map when present" do
      get "/theme-javascripts/#{javascript_cache.digest}.map"
      expect(response.status).to eq(404)

      digest = SecureRandom.hex(20)
      javascript_cache.update(digest: digest, source_map: "{fakeSourceMap: true}")
      get "/theme-javascripts/#{digest}.map"
      expect(response.status).to eq(200)
      expect(response.body).to eq("{fakeSourceMap: true}")

      javascript_cache.destroy
      get "/theme-javascripts/#{digest}.map"
      expect(response.status).to eq(404)
    end
  end

  describe "#show_tests" do
    let(:component) { Fabricate(:theme, component: true, name: "enabled-component") }
    let!(:tests_field) do
      field =
        component.set_field(
          target: :tests_js,
          type: :js,
          name: "acceptance/some-test.js",
          value: "assert.ok(true);",
        )
      component.save!
      field
    end

    before do
      ThemeField.create!(
        theme: component,
        target_id: Theme.targets[:settings],
        name: "yaml",
        value: "num_setting: 5",
      )
      component.save!
    end

    it "forces theme settings default values" do
      component.update_setting(:num_setting, 643)
      _, digest = component.baked_js_tests_with_digest

      get "/theme-javascripts/tests/#{component.id}-#{digest}.js"
      expect(response.body).to include(
        "require(\"discourse/lib/theme-settings-store\").registerSettings(#{component.id}, {\"num_setting\":5}, { force: true });",
      )
      expect(response.body).to include("assert.ok(true);")
    end

    it "includes theme uploads URLs in the settings object" do
      SiteSetting.authorized_extensions = "*"
      js_file = Tempfile.new(%w[vendorlib .js])
      js_file.write("console.log(123);\n")
      js_file.rewind
      js_upload = UploadCreator.new(js_file, "vendorlib.js").create_for(Discourse::SYSTEM_USER_ID)
      component.set_field(
        type: :theme_upload_var,
        target: :common,
        name: "vendorlib",
        upload_id: js_upload.id,
      )
      component.save!
      _, digest = component.baked_js_tests_with_digest

      theme_javascript_hash =
        component.theme_fields.find_by(upload_id: js_upload.id).javascript_cache.digest

      get "/theme-javascripts/tests/#{component.id}-#{digest}.js"
      expect(response.body).to include(
        "require(\"discourse/lib/theme-settings-store\").registerSettings(" +
          "#{component.id}, {\"num_setting\":5,\"theme_uploads\":{\"vendorlib\":" +
          "\"/uploads/default/test_#{ENV["TEST_ENV_NUMBER"].presence || "0"}/original/1X/#{js_upload.sha1}.js\"},\"theme_uploads_local\":{\"vendorlib\":" +
          "\"/theme-javascripts/#{theme_javascript_hash}.js?__ws=test.localhost\"}}, { force: true });",
      )
      expect(response.body).to include("assert.ok(true);")
    ensure
      js_file&.close
      js_file&.unlink
    end

    it "responds with 404 if digest is not a 40 chars hex" do
      digest = Rack::Utils.escape("../../../../../../../../../../etc/passwd").gsub(".", "%2E")
      get "/theme-javascripts/tests/#{component.id}-#{digest}.js"
      expect(response.status).to eq(404)

      get "/theme-javascripts/tests/#{component.id}-abc123.js"
      expect(response.status).to eq(404)
    end

    it "responds with 404 if theme does not exist" do
      get "/theme-javascripts/tests/#{Theme.maximum(:id) + 1}-#{SecureRandom.hex(20)}.js"
      expect(response.status).to eq(404)
    end

    it "responds with 304 if tests digest has not changed" do
      content, digest = component.baked_js_tests_with_digest
      get "/theme-javascripts/tests/#{component.id}-#{digest}.js"
      last_modified = Time.rfc2822(response.headers["Last-Modified"])
      expect(response.status).to eq(200)
      expect(response.headers["Content-Length"].to_i).to eq(content.size)

      get "/theme-javascripts/tests/#{component.id}-#{digest}.js",
          headers: {
            "If-Modified-Since" => (last_modified + 10.seconds).rfc2822,
          }
      expect(response.status).to eq(304)
    end

    it "responds with 404 to requests with old digests" do
      _, old_digest = component.baked_js_tests_with_digest
      get "/theme-javascripts/tests/#{component.id}-#{old_digest}.js"
      expect(response.status).to eq(200)
      expect(response.body).to include("assert.ok(true);")

      tests_field.update!(value: "assert.ok(343434);")
      tests_field.invalidate_baked!
      _, digest = component.baked_js_tests_with_digest
      expect(old_digest).not_to eq(digest)

      get "/theme-javascripts/tests/#{component.id}-#{old_digest}.js"
      expect(response.status).to eq(404)

      get "/theme-javascripts/tests/#{component.id}-#{digest}.js"
      expect(response.status).to eq(200)
      expect(response.body).to include("assert.ok(343434);")
    end
  end
end
