# frozen_string_literal: true

RSpec.describe AuthProviderCredentialsValidator do
  subject(:validator) { described_class.new(name: :enable_twitter_logins) }

  describe "#valid_value?" do
    context "when the provider's credentials are configured" do
      before do
        SiteSetting.twitter_consumer_key = "consumer_key"
        SiteSetting.twitter_consumer_secret = "consumer_secret"
      end

      describe "when value is false" do
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

    context "when the provider's credentials are not configured" do
      before do
        SiteSetting.twitter_consumer_key = ""
        SiteSetting.twitter_consumer_secret = ""
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
            I18n.t(
              "site_settings.errors.auth_provider_credentials_missing",
              settings: "{{setting:twitter_consumer_key}}, {{setting:twitter_consumer_secret}}",
            ),
          )
        end
      end
    end

    context "when only one of the provider's credentials is missing" do
      before do
        SiteSetting.twitter_consumer_key = "consumer_key"
        SiteSetting.twitter_consumer_secret = ""
      end

      it "should not be valid, and should only name the missing credential" do
        expect(validator.valid_value?("t")).to eq(false)

        expect(validator.error_message).to eq(
          I18n.t(
            "site_settings.errors.auth_provider_credentials_missing",
            settings: "{{setting:twitter_consumer_secret}}",
          ),
        )
      end
    end

    context "when no authenticator declares the setting" do
      subject(:validator) { described_class.new(name: :enable_local_logins) }

      it "should be valid" do
        expect(validator.valid_value?("t")).to eq(true)
      end
    end

    # Every setting default is validated as the specs boot, so turning a
    # provider off must never depend on the authenticator registry.
    it "does not look up authenticators when the setting is being turned off" do
      allow(Discourse).to receive(:authenticators).and_call_original

      expect(validator.valid_value?("f")).to eq(true)
      expect(Discourse).not_to have_received(:authenticators)
    end
  end

  describe "enabling the site setting" do
    it "is allowed once the credentials are set" do
      SiteSetting.twitter_consumer_key = "consumer_key"
      SiteSetting.twitter_consumer_secret = "consumer_secret"

      SiteSetting.enable_twitter_logins = true

      expect(SiteSetting.enable_twitter_logins).to eq(true)
    end

    it "is refused with a linkified error when a credential is missing" do
      SiteSetting.twitter_consumer_key = "consumer_key"
      SiteSetting.twitter_consumer_secret = ""

      expect { SiteSetting.enable_twitter_logins = true }.to raise_error(
        Discourse::InvalidHTMLParameters,
      ) do |error|
        expect(error.message).to include("Twitter consumer secret")
        expect(error.message).not_to include("<a", "{{settings")
        expect(error.html_message).to include(
          'class="site-setting-link"',
          ">Twitter consumer secret</a>",
        )
      end

      expect(SiteSetting.enable_twitter_logins).to eq(false)
    end

    it "is allowed when the setting is being turned off" do
      SiteSetting.twitter_consumer_key = ""
      SiteSetting.twitter_consumer_secret = ""

      SiteSetting.enable_twitter_logins = false

      expect(SiteSetting.enable_twitter_logins).to eq(false)
    end
  end
end
