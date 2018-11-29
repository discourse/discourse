require 'rails_helper'

RSpec.describe MetadataController do
  let(:upload) { Fabricate(:upload) }

  describe 'manifest.webmanifest' do
    it 'returns the right output' do
      title = 'MyApp'
      SiteSetting.title = title
      SiteSetting.large_icon = upload

      get "/manifest.webmanifest"
      expect(response.status).to eq(200)
      expect(response.content_type).to eq('application/manifest+json')
      manifest = JSON.parse(response.body)

      expect(manifest["name"]).to eq(title)

      expect(manifest["icons"].first["src"]).to eq(
        UrlHelper.absolute(upload.url)
      )
    end

    it 'can guess mime types' do
      upload = Fabricate(:upload,
        original_filename: 'test.jpg',
        extension: 'jpg'
      )

      SiteSetting.large_icon = upload
      get "/manifest.webmanifest"

      expect(response.status).to eq(200)
      manifest = JSON.parse(response.body)
      expect(manifest["icons"].first["type"]).to eq("image/jpeg")
    end

    it 'defaults to png' do
      SiteSetting.large_icon = upload
      get "/manifest.webmanifest"
      expect(response.status).to eq(200)
      manifest = JSON.parse(response.body)
      expect(manifest["icons"].first["type"]).to eq("image/png")
    end

    it 'defaults to display standalone for Android' do
      get "/manifest.webmanifest", params: {}, headers: { 'USER-AGENT' => 'Mozilla/5.0 (Linux; Android 7.0; SM-G892A Build/NRD90M; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/67.0.3396.87 Mobile Safari/537.36' }
      manifest = JSON.parse(response.body)
      expect(manifest["display"]).to eq("standalone")
    end

    it 'defaults to display browser for iPhone' do
      get "/manifest.webmanifest", params: {}, headers: { 'USER-AGENT' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1' }
      manifest = JSON.parse(response.body)
      expect(manifest["display"]).to eq("browser")
    end

    it 'can be changed to display standalone for iPhones using a site setting' do
      SiteSetting.pwa_display_browser_regex = "a^" # this never matches

      get "/manifest.webmanifest", params: {}, headers: { 'USER-AGENT' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1' }
      manifest = JSON.parse(response.body)
      expect(manifest["display"]).to eq("standalone")
    end

    it 'uses the short_title if it is set' do
      get "/manifest.webmanifest"
      expect(response.status).to eq(200)
      manifest = JSON.parse(response.body)
      expect(manifest).to_not have_key("short_name")

      SiteSetting.short_title = "foo"

      get "/manifest.webmanifest"
      expect(response.status).to eq(200)
      manifest = JSON.parse(response.body)
      expect(manifest["short_name"]).to eq("foo")
    end
  end

  describe 'opensearch.xml' do
    it 'returns the right output' do
      title = 'MyApp'
      SiteSetting.title = title
      SiteSetting.favicon = upload
      get "/opensearch.xml"

      expect(response.status).to eq(200)
      expect(response.body).to include(title)
      expect(response.body).to include("/search?q={searchTerms}")
      expect(response.body).to include('image/png')
      expect(response.body).to include(UrlHelper.absolute(upload.url))
      expect(response.content_type).to eq('application/xml')
    end
  end
end
