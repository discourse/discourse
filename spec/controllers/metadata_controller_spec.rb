require 'rails_helper'

RSpec.describe MetadataController do
  describe 'manifest.json' do
    it 'returns the right output' do

      title = 'MyApp'
      SiteSetting.title = title
      SiteSetting.large_icon_url = "http://big.square/png"

      get :manifest
      expect(response.content_type).to eq('application/json')
      manifest = JSON.parse(response.body)

      expect(manifest["name"]).to eq(title)
      expect(manifest["icons"].first["src"]).to eq("http://big.square/png")
    end
  end

  describe 'opensearch.xml' do
    it 'returns the right output' do
      title = 'MyApp'
      favicon_path = '/uploads/something/23432.png'
      SiteSetting.title = title
      SiteSetting.favicon_url = favicon_path
      get :opensearch, format: :xml
      expect(response.body).to include(title)
      expect(response.body).to include("/search?q={searchTerms}")
      expect(response.body).to include('image/png')
      expect(response.body).to include(favicon_path)
      expect(response.content_type).to eq('application/xml')
    end
  end
end
