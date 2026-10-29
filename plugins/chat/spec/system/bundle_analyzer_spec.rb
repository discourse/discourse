# frozen_string_literal: true

describe "Chat | bundle analyzer" do
  let(:toolbar) { PageObjects::Components::DevTools::Toolbar.new }
  let(:analyzer) { PageObjects::Components::DevTools::BundleAnalyzer.new }

  def open_analyzer
    visit("/latest")
    toolbar.enable
    toolbar.open_bundle_analyzer
    analyzer.dismiss_development_warning
    analyzer.select_scope("plugins")
  end

  it "reports what chat's own build produced" do
    open_analyzer

    expect(analyzer).to have_card("chat")
  end

  it "leaves out a plugin the site has disabled" do
    SiteSetting.chat_enabled = false

    open_analyzer

    expect(analyzer).to have_no_card("chat")
  end
end
