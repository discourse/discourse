# frozen_string_literal: true

require 'rails_helper'

describe 'Bootstrapping the Discourse App' do
  let(:ie_agent) { "Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko" }

  context "when disabled" do
    before do
      SiteSetting.discourse_internet_explorer_enabled = false
    end

    it "does not include the IE stylesheet or Javascript" do
      get "/categories", headers: { "HTTP_USER_AGENT" => ie_agent }
      expect(response.body).not_to match(/discourse-internet-explorer-optional.js/)
      expect(response.body).not_to match(/stylesheets\/discourse-internet-explorer/)
    end
  end

  context "when enabled" do
    before do
      SiteSetting.discourse_internet_explorer_enabled = true
    end

    it "includes the IE js and css" do
      get "/categories", headers: { "HTTP_USER_AGENT" => ie_agent }
      expect(response.body).to match(/discourse-internet-explorer-optional.js/)
      expect(response.body).to match(/stylesheets\/discourse-internet-explorer/)
    end

    it "doesn't include IE stuff for non-IE browsers" do
      get "/categories", headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.70 Safari/537.36" }
      expect(response.body).not_to match(/discourse-internet-explorer-optional.js/)
      expect(response.body).not_to match(/stylesheets\/discourse-internet-explorer/)
    end
  end
end
