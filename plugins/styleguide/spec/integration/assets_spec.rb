# frozen_string_literal: true

RSpec.describe "Styleguide assets" do
  context "when rendering a page" do
    before do
      SiteSetting.styleguide_enabled = true
      sign_in(Fabricate(:admin))
    end

    context "when visiting homepage" do
      it "doesn't load styleguide assets" do
        get "/"
        expect(response.body).to_not include('data-target="styleguide"')
      end
    end

    context "when visiting styleguide" do
      it "loads styleguide assets" do
        get "/styleguide"
        expect(response.body).to include('data-target="styleguide"')
      end
    end
  end

  # The QUnit page resolves plugin JS with no request, so there is no path to match. Without the
  # no-request clause this plugin is dropped before its test bundle is collected and its JS tests
  # cannot run at all; without the `:js` narrowing, stylesheet precompilation — which also has no
  # request — would start pulling this plugin's CSS into every target.
  describe "the asset filter" do
    let(:plugin) { Discourse.plugins.find { |installed| installed.directory_name == "styleguide" } }

    it "keeps JS with no request, so the plugin's own QUnit tests can load" do
      expect(Discourse.apply_asset_filters([plugin], :js, nil)).to eq([plugin])
    end

    it "still drops CSS with no request" do
      expect(Discourse.apply_asset_filters([plugin], :css, nil)).to be_empty
    end

    it "still drops JS on an unrelated page" do
      request = ActionDispatch::TestRequest.create("PATH_INFO" => "/latest")
      expect(Discourse.apply_asset_filters([plugin], :js, request)).to be_empty
    end
  end
end
