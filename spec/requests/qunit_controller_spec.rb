require 'rails_helper'

RSpec.describe QunitController do
  describe "#set_csp_header" do

    it "sets static request.env" do
      nonce = "1234"

      get "/qunit"
      expect(request.env["nonce"]).to eq nonce

      get "/qunit"
      expect(request.env["nonce"]).to eq nonce
    end

    it "sets static X-Discourse-CSP-Nonce header" do
      csp = "script-src 'nonce-1234' 'unsafe-eval';"

      get "/qunit"
      expect(response.headers["Content-Security-Policy"]).to eq csp

      get "/qunit"
      expect(response.headers["Content-Security-Policy"]).to eq csp
    end
  end
end
