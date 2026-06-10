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

    it "serves aliased glyphs for a theme that declares an icon set" do
      theme = Fabricate(:theme)
      fname = "phosphor-multiweight-sprite.svg"
      upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)
      theme.set_field(
        target: :common,
        name: SvgSprite.theme_sprite_variable_name,
        upload_id: upload.id,
        type: :theme_upload_var,
      )
      theme.set_field(
        target: :common,
        name: SvgSprite::ICON_SET_FIELD_NAME,
        type: :json,
        value: { "map" => { "bell" => "ph-regular-bell" } }.to_json,
      )
      theme.save!

      get "/svg-sprite/#{Discourse.current_hostname}/svg-#{theme.id}-#{SvgSprite.version(theme.id)}.js"
      expect(response.status).to eq(200)
      expect(response.body).to include("M128 24a8") # the Phosphor glyph, aliased onto #bell
      expect(response.body).not_to include("ph-regular-bell") # raw id not served
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
      get "/svg-sprite/search/bolt"
      expect(response.status).to eq(404)
    end

    it "should return symbol for FA icon search" do
      sign_in(user)

      get "/svg-sprite/search/bolt"
      expect(response.status).to eq(200)
      expect(response.body).to include("bolt")
    end

    it "should return 404 when looking for non-existent FA icon" do
      sign_in(user)

      get "/svg-sprite/search/not-a-valid-icon"
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

      get "/svg-sprite/search/my-custom-theme-icon"
      expect(response.status).to eq(200)
      expect(response.body).to include("my-custom-theme-icon")
    end
  end

  describe "#icon_picker_search" do
    it "should return 403 for anonymous users" do
      get "/svg-sprite/picker-search"

      expect(response.status).to eq(403)
    end

    it "should work with no filter and return one page of results" do
      sign_in(user)
      get "/svg-sprite/picker-search"

      expect(response.status).to eq(200)

      data = response.parsed_body["icons"]
      expect(data.length).to eq(SvgSpriteController::ICONS_PER_PAGE)
      expect(data[0]["id"]).to be_in(SvgSprite.all_icons)
    end

    it "should filter" do
      sign_in(user)

      get "/svg-sprite/picker-search", params: { filter: "500px", only_available: "false" }

      expect(response.status).to eq(200)

      data = response.parsed_body["icons"]
      expect(data.length).to eq(1)
      expect(data[0]["id"]).to eq("fab-500px")
      expect(response.parsed_body["has_more"]).to eq(false)
    end

    it "paginates and reports whether more pages exist" do
      sign_in(user)

      get "/svg-sprite/picker-search", params: { only_available: "false" }
      first_page = response.parsed_body

      get "/svg-sprite/picker-search", params: { only_available: "false", page: 1 }
      second_page = response.parsed_body

      expect(first_page["icons"].length).to eq(SvgSpriteController::ICONS_PER_PAGE)
      expect(first_page["has_more"]).to eq(true)
      expect(second_page["icons"].length).to eq(SvgSpriteController::ICONS_PER_PAGE)
      expect(
        first_page["icons"].map { |i| i["id"] } & second_page["icons"].map { |i| i["id"] },
      ).to be_empty
    end

    it "returns an empty page past the last one" do
      sign_in(user)

      get "/svg-sprite/picker-search", params: { page: 999 }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("icons" => [], "has_more" => false)
    end

    it "rejects a negative, non-numeric, or absurdly large page" do
      sign_in(user)

      ["-1", "not-a-number", ["1"], "99999999999999999999999999"].each do |page|
        get "/svg-sprite/picker-search", params: { page: }

        expect(response.status).to eq(400)
      end
    end

    it "lists the icons in the sprite before the rest" do
      sign_in(user)

      get "/svg-sprite/picker-search", params: { only_available: "false" }

      available = SvgSprite.all_icons
      ids = response.parsed_body["icons"].map { |i| i["id"] }

      expect(ids.first).to be_in(available)
      expect(ids).to eq(ids.sort_by { |id| [available.include?(id) ? 0 : 1, id] })
    end

    it "keeps the restricted set when only_available is blank" do
      sign_in(user)

      get "/svg-sprite/picker-search", params: { only_available: "" }

      beer_icon = response.parsed_body["icons"].find { |i| i["id"] == "beer-mug-empty" }
      expect(beer_icon).to be nil
    end

    it "returns every icon when only_available is false" do
      sign_in(user)

      get "/svg-sprite/picker-search", params: { only_available: "false", filter: "beer" }

      beer_icon = response.parsed_body["icons"].find { |i| i["id"] == "beer-mug-empty" }
      expect(beer_icon).to be_present
    end

    it "revalidates with an etag until the sprite changes" do
      sign_in(user)

      get "/svg-sprite/picker-search"
      etag = response.headers["ETag"]
      expect(etag).to be_present

      get "/svg-sprite/picker-search", headers: { "HTTP_IF_NONE_MATCH" => etag }
      expect(response.status).to eq(304)

      Fabricate(:badge, name: "Seedling Badge", icon: "seedling")

      get "/svg-sprite/picker-search", headers: { "HTTP_IF_NONE_MATCH" => etag }
      expect(response.status).to eq(200)
    end

    it "should display only available" do
      sign_in(user)

      get "/svg-sprite/picker-search", params: { only_available: "true", filter: "beer" }
      expect(response.parsed_body["icons"]).to eq([])

      get "/svg-sprite/picker-search", params: { only_available: "true" }
      expect(response.parsed_body["icons"].length).to be > 0
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
