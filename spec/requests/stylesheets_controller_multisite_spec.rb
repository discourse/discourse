# frozen_string_literal: true

RSpec.describe StylesheetsController, type: %i[multisite request] do
  after do
    %w[default second].each do |db|
      test_multisite_connection(db) { Stylesheet::Manager.rm_cache_folder }
    end
  end

  it "keeps a separate disk cache per site" do
    digest = SecureRandom.hex(20)

    test_multisite_connection("default") do
      StylesheetCache.add("desktop_theme_1", digest, "body { color: red; }", nil)

      get "/stylesheets/desktop_theme_1_#{digest}.css"
      expect(response.body).to eq("body { color: red; }")
    end

    test_multisite_connection("second") do
      StylesheetCache.add("desktop_theme_1", digest, "body { color: blue; }", nil)

      get "http://test2.localhost/stylesheets/desktop_theme_1_#{digest}.css"
      expect(response.body).to eq("body { color: blue; }")
    end
  end
end
