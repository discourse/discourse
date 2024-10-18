# frozen_string_literal: true

RSpec.describe SvgSpriteController do
  fab!(:user)

  describe "#show" do
    before { SvgSprite.expire_cache }

    it "should return bundle when version is current" do
      get "/svg-sprite/#{Discourse.current_hostname}/svg--#{SvgSprite.version}.js"
      expect(response.status).to eq(200)

      theme = Fabricate(:theme)
      theme.set_field(target: :settings, name: :yaml, value: "custom_icon: dragon")
      theme.save!
      get "/svg-sprite/#{Discourse.current_hostname}/svg-#{theme.id}-#{SvgSprite.version(theme.id)}.js"
      expect(response.status).to eq(200)
    end

    it "should redirect to current version" do
      random_hash = Digest::SHA1.hexdigest("somerandomstring")
      get "/svg-sprite/#{Discourse.current_hostname}/svg--#{random_hash}.js"

      expect(response).to redirect_to("/svg-sprite/test.localhost/svg--#{SvgSprite.version}.js")

      set_cdn_url "//some-cdn.com/site"

      get "/svg-sprite/#{Discourse.current_hostname}/svg--#{random_hash}.js"

      expect(response).to redirect_to(
        "https://some-cdn.com/site/svg-sprite/test.localhost/svg--#{SvgSprite.version}.js",
      )
    end
  end

  describe "#search" do
    it "should not work for anons" do
      get "/svg-sprite/search/fa-bolt"
      expect(response.status).to eq(404)
    end

    it "should return symbol for FA icon search" do
      sign_in(user)

      get "/svg-sprite/search/fa-bolt"
      expect(response.status).to eq(200)
      expect(response.body).to include("bolt")
    end

    it "should return 404 when looking for non-existent FA icon" do
      sign_in(user)

      get "/svg-sprite/search/fa-not-a-valid-icon"
      expect(response.status).to eq(404)
    end

    it "should find a custom icon in default theme" do
      theme = Fabricate(:theme)
      fname = "custom-theme-icon-sprite.svg"

      upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

      theme.set_field(
        target: :common,
        name: SvgSprite.theme_sprite_variable_name,
        upload_id: upload.id,
        type: :theme_upload_var,
      )
      theme.save!

      SiteSetting.default_theme_id = theme.id

      sign_in(user)

      get "/svg-sprite/search/fa-my-custom-theme-icon"
      expect(response.status).to eq(200)
      expect(response.body).to include("my-custom-theme-icon")
    end
  end

  describe "#icon_picker_search" do
    it "should return 403 for anonymous users" do
      get "/svg-sprite/picker-search"

      expect(response.status).to eq(403)
    end

    it "should work with no filter and max out at 500 results" do
      sign_in(user)
      get "/svg-sprite/picker-search"

      expect(response.status).to eq(200)

      data = response.parsed_body
      expect(data.length).to be <= 500
      expect(data[0]["id"]).to eq("0")
    end

    it "should filter" do
      sign_in(user)

      get "/svg-sprite/picker-search", params: { filter: "500px" }

      expect(response.status).to eq(200)

      data = response.parsed_body
      expect(data.length).to eq(1)
      expect(data[0]["id"]).to eq("fab-500px")
    end

    it "should display only available" do
      sign_in(user)

      get "/svg-sprite/picker-search"
      data = response.parsed_body
      beer_icon = response.parsed_body.find { |i| i["id"] == "beer-mug-empty" }
      expect(beer_icon).to be_present

      get "/svg-sprite/picker-search", params: { only_available: "true" }
      data = response.parsed_body
      beer_icon = response.parsed_body.find { |i| i["id"] == "beer-mug-empty" }
      expect(beer_icon).to be nil
      expect(data.length).to eq(250)
    end
  end

  describe "#svg_icon" do
    it "requires .svg extension" do
      get "/svg-sprite/#{Discourse.current_hostname}/icon/bolt"
      expect(response.status).to eq(404)
    end

    it "returns SVG given an icon name" do
      get "/svg-sprite/#{Discourse.current_hostname}/icon/bolt.svg"
      expect(response.status).to eq(200)
      expect(response.body).to include("bolt")
    end

    it "returns SVG given an icon name and a color" do
      get "/svg-sprite/#{Discourse.current_hostname}/icon/CC0000/fab-github.svg"
      expect(response.status).to eq(200)

      expect(response.body).to include("fab-github")
      expect(response.body).to include('fill="#CC0000"')
      expect(response.headers["Cache-Control"]).to eq("max-age=86400, public, immutable")
    end

    it "returns SVG given an icon name and a 3-character HEX color" do
      get "/svg-sprite/#{Discourse.current_hostname}/icon/C00/fab-github.svg"
      expect(response.status).to eq(200)

      expect(response.body).to include("fab-github")
      expect(response.body).to include('fill="#CC0000"')
      expect(response.headers["Cache-Control"]).to eq("max-age=86400, public, immutable")
    end

    it "ignores non-HEX colors" do
      get "/svg-sprite/#{Discourse.current_hostname}/icon/orange/fab-github.svg"
      expect(response.status).to eq(404)
    end
  end
end
