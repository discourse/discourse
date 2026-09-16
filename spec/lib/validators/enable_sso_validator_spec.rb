# frozen_string_literal: true

RSpec.describe EnableSsoValidator do
  subject(:validator) { described_class.new }

  describe "#valid_value?" do
    describe "when 'sso url' is empty" do
      before { SiteSetting.discourse_connect_url = "" }

      describe "when val is false" do
        it "accepts disabling DiscourseConnect" do
          expect(validator.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "rejects enabling DiscourseConnect without a URL" do
          expect(validator.valid_value?("t")).to eq(false)

          expect(validator.error_message).to eq(
            I18n.t("site_settings.errors.discourse_connect_url_is_empty"),
          )
        end
      end
    end

    describe "when 'sso url' is present" do
      before do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.discourse_connect_secret = "x" * 10
      end

      describe "when value is false" do
        it "accepts disabling DiscourseConnect" do
          expect(validator.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "accepts enabling DiscourseConnect" do
          expect(validator.valid_value?("t")).to eq(true)
        end
      end
    end

    describe "when 'sso secret' is blank" do
      before { SiteSetting.discourse_connect_url = "https://www.example.com/sso" }

      describe "when val is false" do
        it "accepts disabling DiscourseConnect" do
          expect(validator.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "rejects enabling DiscourseConnect without a secret" do
          expect(validator.valid_value?("t")).to eq(false)

          expect(validator.error_message).to eq(
            I18n.t("site_settings.errors.discourse_connect_secret_is_too_short"),
          )
        end
      end
    end

    describe "when 'sso secret' is shorter than the minimum length" do
      before do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.discourse_connect_secret = "x" * 9
      end

      describe "when value is true" do
        it "rejects enabling DiscourseConnect with a short secret" do
          expect(validator.valid_value?("t")).to eq(false)

          expect(validator.error_message).to eq(
            I18n.t("site_settings.errors.discourse_connect_secret_is_too_short"),
          )
        end
      end
    end

    describe "when 2FA is enforced" do
      before do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.discourse_connect_secret = "x" * 10
      end

      it "rejects enabling DiscourseConnect when second factor is enforced" do
        SiteSetting.enforce_second_factor = "all"

        expect(validator.valid_value?("t")).to eq(false)
      end

      it "accepts enabling DiscourseConnect when second factor is optional" do
        SiteSetting.enforce_second_factor = "no"

        expect(validator.valid_value?("t")).to eq(true)
      end
    end
  end
end
