require 'rails_helper'

describe SvgSpriteController do

  before do
    SvgSprite.rebuild_cache
  end

  context 'show' do
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
end
