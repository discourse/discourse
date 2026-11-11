# frozen_string_literal: true

RSpec.describe ThemeJavascriptsController, type: %i[multisite request] do
  after { FileUtils.rm_rf(ThemeJavascriptsController::DISK_CACHE_PATH) }

  def create_javascript_cache(content, digest)
    JavascriptCache.create!(content:, theme: Fabricate(:theme)).update_columns(digest:)
  end

  it "keeps a separate disk cache per site" do
    digest = SecureRandom.hex(20)

    test_multisite_connection("default") do
      create_javascript_cache("console.log('default');", digest)

      get "/theme-javascripts/#{digest}.js"
      expect(response.body).to eq("console.log('default');")
    end

    test_multisite_connection("second") do
      create_javascript_cache("console.log('second');", digest)

      get "http://test2.localhost/theme-javascripts/#{digest}.js"
      expect(response.body).to eq("console.log('second');")
    end
  end
end
