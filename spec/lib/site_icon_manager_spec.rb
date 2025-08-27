# frozen_string_literal: true

RSpec.describe SiteIconManager do
  fab!(:mobile_logo_image) { Fabricate(:image_upload, color: "black", width: 400, height: 120) }
  fab!(:mobile_logo_dark_image) do
    Fabricate(:image_upload, color: "white", width: 400, height: 120)
  end

  fab!(:logo_image) { Fabricate(:image_upload, color: "black", width: 600, height: 80) }
  fab!(:logo_dark_image) { Fabricate(:image_upload, color: "white", width: 600, height: 80) }

  before { SiteIconManager.enable }

  let(:upload) do
    UploadCreator.new(file_from_fixtures("smallest.png"), "logo.png").create_for(
      Discourse.system_user.id,
    )
  end

  it "works correctly" do
    SiteSetting.logo = nil
    SiteSetting.logo_small = nil

    # Falls back to sketch for some icons
    expect(SiteIconManager.favicon.upload_id).to eq(SiteIconManager::SKETCH_LOGO_ID)
    expect(SiteIconManager.mobile_logo).to eq(nil)

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
      SiteSetting.mobile_logo = nil
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
      SiteSetting.mobile_logo_dark = nil
      expect(SiteIconManager.mobile_logo_dark_url).to eq(
        GlobalPath.full_cdn_url(logo_dark_image.url),
      )
    end
  end
end
