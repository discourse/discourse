# frozen_string_literal: true

describe DiscourseAi::Configuration::DiscoverEnabledValidator do
  before { enable_current_plugin }

  after do
    SiteSetting.provider.destroy(:ai_discover_enabled)
    SiteSetting.refresh!
  end

  it "rejects enabling Discover when it is currently disabled" do
    expect { SiteSetting.ai_discover_enabled = true }.to raise_error(
      Discourse::InvalidParameters,
      /cannot be enabled/,
    )
  end

  it "allows an existing Discover site to keep or disable it" do
    SiteSetting.provider.save(:ai_discover_enabled, "t", SiteSetting.types[:bool])
    SiteSetting.refresh!

    SiteSetting.ai_discover_enabled = true
    expect(SiteSetting.ai_discover_enabled).to eq(true)

    SiteSetting.ai_discover_enabled = false
    expect(SiteSetting.ai_discover_enabled).to eq(false)
  end
end
