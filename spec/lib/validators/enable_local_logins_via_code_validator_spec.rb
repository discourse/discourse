# frozen_string_literal: true

RSpec.describe EnableLocalLoginsViaCodeValidator do
  subject(:validator) { described_class.new }

  describe "#valid_value?" do
    describe "when 'enable_local_logins' is false" do
      before { SiteSetting.enable_local_logins = false }

      it "allows disabling" do
        expect(validator.valid_value?("f")).to eq(true)
      end

      it "does not allow enabling" do
        expect(validator.valid_value?("t")).to eq(false)

        expect(validator.error_message).to eq(
          I18n.t("site_settings.errors.enable_local_logins_disabled"),
        )
      end
    end

    describe "when 'enable_local_logins_via_email' is false" do
      before { SiteSetting.enable_local_logins_via_email = false }

      it "allows disabling" do
        expect(validator.valid_value?("f")).to eq(true)
      end

      it "does not allow enabling" do
        expect(validator.valid_value?("t")).to eq(false)

        expect(validator.error_message).to eq(
          I18n.t("site_settings.errors.enable_local_logins_via_email_disabled"),
        )
      end
    end

    describe "when 'enable_discourse_connect' is true" do
      before do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.discourse_connect_secret = "x" * 10
        SiteSetting.enable_discourse_connect = true
      end

      it "allows disabling" do
        expect(validator.valid_value?("f")).to eq(true)
      end

      it "does not allow enabling" do
        expect(validator.valid_value?("t")).to eq(false)

        expect(validator.error_message).to eq(
          I18n.t("site_settings.errors.discourse_connect_enabled"),
        )
      end
    end

    describe "when local logins are enabled and discourse connect is disabled" do
      before do
        SiteSetting.enable_local_logins = true
        SiteSetting.enable_discourse_connect = false
      end

      it "allows disabling" do
        expect(validator.valid_value?("f")).to eq(true)
      end

      it "allows enabling" do
        expect(validator.valid_value?("t")).to eq(true)
      end
    end
  end
end
