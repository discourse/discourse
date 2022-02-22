# frozen_string_literal: true

require 'rails_helper'

class GlobalPathInstance
  extend GlobalPath
end

describe SiteIconManager do
  before do
    SiteIconManager.enable
  end

  let(:upload) do
    UploadCreator.new(file_from_fixtures("smallest.png"), 'logo.png').create_for(Discourse.system_user.id)
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
    expect(SiteSetting.site_manifest_icon_url).to eq(GlobalPathInstance.full_cdn_url(manifest.url))
  end

end
