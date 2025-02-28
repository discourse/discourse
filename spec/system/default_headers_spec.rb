# frozen_string_literal: true
describe "Default Headers", type: :system do
  context "when a public exception(like RoutingError) is raised" do
    context "when requesting an HTML page" do
      let(:html_path) { "/nonexistent" }

      it "sets the Cross-Origin-Opener-Policy header" do
        SiteSetting.bootstrap_error_pages = true
        get html_path # triggers a RoutingError, handled by the exceptions_app
        expect(response.headers).to have_key("Cross-Origin-Opener-Policy")
        expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("same-origin-allow-popups")
      end
    end

    context "when requesting a JSON response for an invalid URL" do
      let(:json_path) { "/nonexistent.json" }

      it "does not include the Cross-Origin-Opener-Policy header" do
        SiteSetting.bootstrap_error_pages = true
        SiteSetting.cross_origin_opener_policy_header = "same-origin"
        get json_path
        expect(response.headers["Cross-Origin-Opener-Policy"]).to be_nil
      end
    end
  end
end
