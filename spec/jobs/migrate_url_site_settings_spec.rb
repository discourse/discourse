require 'rails_helper'

RSpec.describe Jobs::MigrateUrlSiteSettings do
  before do
    SiteSetting.authorized_extensions = ''
  end

  it 'should migrate to the new upload site settings correctly' do
    [
      %w{logo_url /test.png},
      %w{logo_small_url https://test.discourse.awesome/test.png},
      %w{favicon_url http://test.discourse.awesome/some.ico},
      %w{digest_logo_url /test.png},
      %w{mobile_logo_url /test.png},
      %w{large_icon_url /test.png},
      %w{apple_touch_icon_url /test.png},
      %w{default_opengraph_image_url /test.png},
      %w{twitter_summary_large_image_url //omg.aws.somestack/test.png},
      %w{push_notifications_icon_url //omg.aws.somestack/test.png}
    ].each do |name, value|

      SiteSetting.create!(
        name: name,
        value: value,
        data_type: SiteSettings::TypeSupervisor.types[:string]
      )
    end

    %w{
      http://test.localhost/test.png
      https://omg.aws.somestack/test.png
    }.each do |url|
      stub_request(:get, url).to_return(
        status: 200, body: file_from_fixtures("smallest.png").read
      )
    end

    stub_request(:get, "https://test.discourse.awesome/test.png")
      .to_return(status: 200, body: file_from_fixtures("downsized.png").read)

    stub_request(:get, "http://test.discourse.awesome/some.ico")
      .to_return(status: 200, body: file_from_fixtures("smallest.ico").read)

    expect do
      described_class.new.execute_onceoff({})
    end.to change { Upload.count }.by(3)

    upload = Upload.find_by(original_filename: "logo.png")
    upload2 = Upload.find_by(original_filename: "logo_small.png")
    upload3 = Upload.find_by(original_filename: "favicon.ico")

    expect(SiteSetting.logo_small).to eq(upload2)
    expect(SiteSetting.logo_small.is_a?(Upload)).to eq(true)

    expect(SiteSetting.favicon).to eq(upload3)
    expect(SiteSetting.favicon.is_a?(Upload)).to eq(true)

    %i{
      logo
      digest_logo
      mobile_logo
      large_icon
      apple_touch_icon
      opengraph_image
      twitter_summary_large_image
      push_notifications_icon
    }.each do |setting|
      expect(SiteSetting.public_send(setting)).to eq(upload)
      expect(SiteSetting.public_send(setting).is_a?(Upload)).to eq(true)
    end
  end
end
