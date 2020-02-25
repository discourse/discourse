# frozen_string_literal: true

require 'rails_helper'

describe SvgSpriteController do

  context 'show' do
    before do
      SvgSprite.expire_cache
    end

    it "should return bundle when version is current" do
      get "/svg-sprite/#{Discourse.current_hostname}/svg--#{SvgSprite.version}.js"
      expect(response.status).to eq(200)

      theme = Fabricate(:theme)
      theme.set_field(target: :settings, name: :yaml, value: "custom_icon: dragon")
      theme.save!
      get "/svg-sprite/#{Discourse.current_hostname}/svg-#{theme.id}-#{SvgSprite.version([theme.id])}.js"
      expect(response.status).to eq(200)
    end

    it "should redirect to current version" do
      random_hash = Digest::SHA1.hexdigest("somerandomstring")
      get "/svg-sprite/#{Discourse.current_hostname}/svg--#{random_hash}.js"

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

    it "should find a custom icon in default theme" do
      theme = Fabricate(:theme)
      fname = "custom-theme-icon-sprite.svg"

      upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

      theme.set_field(target: :common, name: SvgSprite.theme_sprite_variable_name, upload_id: upload.id, type: :theme_upload_var)
      theme.save!

      SiteSetting.default_theme_id = theme.id

      user = sign_in(Fabricate(:user))

      get "/svg-sprite/search/fa-my-custom-theme-icon"
      expect(response.status).to eq(200)
      expect(response.body).to include('my-custom-theme-icon')
    end
  end

  context 'icon_picker_search' do
    it 'should work with no filter and max out at 200 results' do
      user = sign_in(Fabricate(:user))
      get '/svg-sprite/picker-search'

      expect(response.status).to eq(200)

      data = JSON.parse(response.body)
      expect(data.length).to eq(200)
      expect(data[0]["id"]).to eq("ad")
    end

    it 'should filter' do
      user = sign_in(Fabricate(:user))

      get '/svg-sprite/picker-search', params: { filter: '500px' }

      expect(response.status).to eq(200)

      data = JSON.parse(response.body)
      expect(data.length).to eq(1)
      expect(data[0]["id"]).to eq("fab-500px")
    end
  end
end
