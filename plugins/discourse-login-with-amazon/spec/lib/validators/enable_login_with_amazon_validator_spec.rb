# frozen_string_literal: true

require "rails_helper"

RSpec.describe EnableLoginWithAmazonValidator do
  subject(:validator) { described_class.new }

  describe "#valid_value?" do
    describe "when login_with_amazon_client_id and login_with_amazon_client_secret has not been set" do
      it "should return true when value is false" do
        expect(validator.valid_value?("f")).to eq(true)
      end

      it "should return false when value is true" do
        expect(validator.valid_value?("t")).to eq(false)

        expect(validator.error_message).to eq(
          I18n.t("site_settings.errors.login_with_amazon_client_id_is_blank"),
        )

        SiteSetting.login_with_amazon_client_id = "somekey"

        expect(validator.valid_value?("t")).to eq(false)

        expect(validator.error_message).to eq(
          I18n.t("site_settings.errors.login_with_amazon_client_secret_is_blank"),
        )
      end
    end

    describe "when login_with_amazon_client_id and login_with_amazon_client_secret has been set" do
      before do
        SiteSetting.login_with_amazon_client_id = "somekey"
        SiteSetting.login_with_amazon_client_secret = "somesecretkey"
      end

      it "should return true when value is false" do
        expect(validator.valid_value?("f")).to eq(true)
      end

      it "should return true when value is true" do
        expect(validator.valid_value?("t")).to eq(true)
      end
    end
  end
end
