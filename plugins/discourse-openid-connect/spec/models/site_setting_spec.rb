# frozen_string_literal: true

describe SiteSetting do
  describe "openid_connect_email_claim" do
    it "rejects empty and whitespace-only claim names" do
      ["", " \t\n"].each do |value|
        expect { SiteSetting.openid_connect_email_claim = value }.to raise_error(
          Discourse::InvalidParameters,
        )
      end
    end

    it "accepts a custom claim name" do
      SiteSetting.openid_connect_email_claim = "mail"

      expect(SiteSetting.openid_connect_email_claim).to eq("mail")
    end
  end
end
