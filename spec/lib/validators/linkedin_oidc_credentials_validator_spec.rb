# frozen_string_literal: true

RSpec.describe LinkedinOidcCredentialsValidator do
  subject(:validator) { described_class.new }

  describe "#valid_value?" do
    describe "when OIDC authentication credentials are configured" do
      before do
        SiteSetting.linkedin_oidc_client_id = "foo"
        SiteSetting.linkedin_oidc_client_secret = "bar"
      end

      describe "when val is false" do
        it "should be valid" do
          expect(validator.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "should be valid" do
          expect(validator.valid_value?("t")).to eq(true)
        end
      end
    end

    describe "when OIDC authentication credentials are not configured" do
      before do
        SiteSetting.linkedin_oidc_client_id = ""
        SiteSetting.linkedin_oidc_client_secret = ""
      end

      describe "when value is false" do
        it "should be valid" do
          expect(validator.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "should not be valid" do
          expect(validator.valid_value?("t")).to eq(false)

          expect(validator.error_message).to eq(
            I18n.t("site_settings.errors.linkedin_oidc_credentials"),
          )
        end
      end
    end
  end
end
