require 'rails_helper'

describe SvgSpriteController do

  context 'show' do
    before do
      SvgSprite.rebuild_cache
    end

    it "should return bundle when version is current" do
      get "/svg-sprite/#{Discourse.current_hostname}/svg-#{SvgSprite.version}.js"
      expect(response.status).to eq(200)
    end

    it "should redirect to current version" do
      random_hash = Digest::SHA1.hexdigest("somerandomstring")
      get "/svg-sprite/#{Discourse.current_hostname}/svg-#{random_hash}.js"

      expect(response.status).to eq(302)
      expect(response.location).to include(SvgSprite.version)
    end
  end

  context 'search' do
    it "should not work for anons" do
      get "/svg-sprite/search/fa-bolt"
      expect(response.status).to eq(404)
    end

    it "should return symbol for FA icon search" do
      user = sign_in(Fabricate(:user))

      get "/svg-sprite/search/fa-bolt"
      expect(response.status).to eq(200)
      expect(response.body).to include('bolt')
    end

    it "should return 404 when looking for non-existent FA icon" do
      user = sign_in(Fabricate(:user))

      get "/svg-sprite/search/fa-not-a-valid-icon"
      expect(response.status).to eq(404)
    end
  end
end
