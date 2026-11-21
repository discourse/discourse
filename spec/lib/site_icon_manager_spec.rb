# frozen_string_literal: true

RSpec.describe SiteIconManager do
  fab!(:mobile_logo_image) { Fabricate(:image_upload, color: "black", width: 400, height: 120) }
  fab!(:mobile_logo_dark_image) do
    Fabricate(:image_upload, color: "white", width: 400, height: 120)
  end

  fab!(:logo_image) { Fabricate(:image_upload, color: "black", width: 600, height: 80) }
  fab!(:logo_dark_image) { Fabricate(:image_upload, color: "white", width: 600, height: 80) }
  fab!(:small_logo_image) { Fabricate(:image_upload, color: "black", width: 120, height: 120) }
  fab!(:small_logo_dark_image) { Fabricate(:image_upload, color: "white", width: 120, height: 120) }

  before { SiteIconManager.enable }

  let(:upload) do
    UploadCreator.new(file_from_fixtures("smallest.png"), "logo.png").create_for(
      Discourse.system_user.id,
    )
  end

  it "works correctly" do
    SiteSetting.logo = ""
    SiteSetting.logo_small = ""

    # Falls back to sketch for some icons
    expect(SiteIconManager.favicon.upload_id).to eq(SiteIconManager::SKETCH_LOGO_ID)
    expect(SiteIconManager.mobile_logo).to eq(nil)
  end

  it "handles missing sketch logo gracefully" do
    SiteSetting.logo = ""
    SiteSetting.logo_small = ""

    Upload.find_by(id: SiteIconManager::SKETCH_LOGO_ID)&.delete

    expect(SiteIconManager.favicon).to eq(nil)
    expect(SiteIconManager.large_icon).to eq(nil)
    expect(SiteIconManager.mobile_logo).to eq(nil)
    expect(SiteIconManager.opengraph_image).to eq(nil)
  end

  it "resizes icons correctly" do
    SiteSetting.logo_small = upload

    # Always resizes to 512x512
    manifest = SiteIconManager.manifest_icon
    expect(manifest.upload_id).to eq(upload.id)
    expect(manifest.width).to eq(512)
    expect(manifest.height).to eq(512)

    # Always resizes to 32x32
    favicon = SiteIconManager.favicon
    expect(favicon.upload_id).to eq(upload.id)
    expect(favicon.width).to eq(32)
    expect(favicon.height).to eq(32)

    # Don't resize
    opengraph = SiteIconManager.opengraph_image
    expect(opengraph).to eq(upload)

    # Site Setting integration
    expect(SiteSetting.manifest_icon).to eq(nil)
    expect(SiteSetting.site_manifest_icon_url).to eq(GlobalPath.full_cdn_url(manifest.url))
  end

  describe ".mobile_logo_url" do
    before do
      SiteSetting.logo = logo_image
      SiteSetting.mobile_logo = mobile_logo_image
    end

    it "returns the upload URL for the mobile_logo site setting" do
      expect(SiteIconManager.mobile_logo_url).to eq(GlobalPath.full_cdn_url(mobile_logo_image.url))
    end

    it "returns the upload URL for the logo site setting when the mobile_logo setting isn't set" do
      SiteSetting.mobile_logo = ""
      expect(SiteIconManager.mobile_logo_url).to eq(GlobalPath.full_cdn_url(logo_image.url))
    end
  end

  describe ".mobile_logo_dark_url" do
    before do
      SiteSetting.logo_dark = logo_dark_image
      SiteSetting.mobile_logo_dark = mobile_logo_dark_image
    end

    it "returns the upload URL for the mobile_logo_dark site setting" do
      expect(SiteIconManager.mobile_logo_dark_url).to eq(
        GlobalPath.full_cdn_url(mobile_logo_dark_image.url),
      )
    end

    it "returns the upload URL for the logo_dark site setting when the mobile_logo_dark setting isn't set" do
      SiteSetting.mobile_logo_dark = ""
      expect(SiteIconManager.mobile_logo_dark_url).to eq(
        GlobalPath.full_cdn_url(logo_dark_image.url),
      )
    end
  end

  describe "using the small logo on mobile" do
    before do
      SiteSetting.logo = logo_image
      SiteSetting.logo_dark = logo_dark_image
      SiteSetting.logo_small = small_logo_image
      SiteSetting.logo_small_dark = small_logo_dark_image
    end

    it "keeps the primary logos by default and refreshes the cached URLs when enabled" do
      expect(SiteIconManager.mobile_logo_url).to eq(GlobalPath.full_cdn_url(logo_image.url))
      expect(SiteIconManager.mobile_logo_dark_url).to eq(
        GlobalPath.full_cdn_url(logo_dark_image.url),
      )

      SiteSetting.use_small_logo_on_mobile = true

      expect(SiteIconManager.mobile_logo_url).to eq(GlobalPath.full_cdn_url(small_logo_image.url))
      expect(SiteIconManager.mobile_logo_dark_url).to eq(
        GlobalPath.full_cdn_url(small_logo_dark_image.url),
      )

      SiteSetting.logo_small_dark = ""
      expect(SiteIconManager.mobile_logo_dark_url).to eq("")
    end

    it "prefers uploaded mobile logos and keeps the primary fallback without a small logo" do
      SiteSetting.use_small_logo_on_mobile = true
      SiteSetting.mobile_logo_dark = mobile_logo_dark_image

      expect(SiteIconManager.mobile_logo_dark).to eq(mobile_logo_dark_image)

      SiteSetting.mobile_logo = mobile_logo_image
      SiteSetting.mobile_logo_dark = ""

      expect(SiteIconManager.mobile_logo).to eq(mobile_logo_image)
      expect(SiteIconManager.mobile_logo_dark).to eq(logo_dark_image)

      SiteSetting.mobile_logo = ""
      SiteSetting.logo_small = ""

      expect(SiteIconManager.mobile_logo).to eq(logo_image)
      expect(SiteIconManager.mobile_logo_dark).to eq(logo_dark_image)
    end
  end
end
