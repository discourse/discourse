# frozen_string_literal: true

describe "Bundle analyzer" do
  let(:toolbar) { PageObjects::Components::DevTools::Toolbar.new }
  let(:analyzer) { PageObjects::Components::DevTools::BundleAnalyzer.new }

  before do
    visit("/latest")
    toolbar.enable
    toolbar.open_bundle_analyzer
  end

  it "warns that a development build's sizes are not what anyone downloads" do
    expect(analyzer).to have_development_warning
    expect(analyzer).to have_no_report

    analyzer.dismiss_development_warning

    expect(analyzer).to have_no_development_warning
    expect(analyzer).to have_report

    # Only a production build compresses, so there is nothing to report here.
    expect(analyzer).to have_unmeasured_sizes
  end

  it "lists what the page loaded, and narrows to a filter" do
    analyzer.dismiss_development_warning

    expect(analyzer).to have_card("discourse")

    analyzer.filter("No Such Module Anywhere")

    expect(analyzer).to have_no_card("discourse")
    expect(analyzer.filter_text).to eq("No Such Module Anywhere")
  end

  it "opens a card on click, and closes it again" do
    analyzer.dismiss_development_warning

    expect(analyzer).to have_no_expanded_card("discourse")

    analyzer.toggle_card("discourse")

    expect(analyzer).to have_expanded_card("discourse")

    analyzer.toggle_card("discourse")

    expect(analyzer).to have_no_expanded_card("discourse")
  end

  it "shows plugins and core separately" do
    analyzer.dismiss_development_warning
    analyzer.select_scope("plugins")

    expect(analyzer).to have_no_card("discourse")

    analyzer.select_scope("core")

    expect(analyzer).to have_card("discourse")
  end
end
