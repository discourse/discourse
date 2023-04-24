# frozen_string_literal: true

RSpec.describe EnableSsoValidator do
  subject { described_class.new }

  describe "#valid_value?" do
    describe "when 'sso url' is empty" do
      before { SiteSetting.discourse_connect_url = "" }

      describe "when val is false" do
        it "should be valid" do
          expect(subject.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "should not be valid" do
          expect(subject.valid_value?("t")).to eq(false)

          expect(subject.error_message).to eq(
            I18n.t("site_settings.errors.discourse_connect_url_is_empty"),
          )
        end
      end
    end

    describe "when 'sso url' is present" do
      before { SiteSetting.discourse_connect_url = "https://www.example.com/sso" }

      describe "when value is false" do
        it "should be valid" do
          expect(subject.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "should be valid" do
          expect(subject.valid_value?("t")).to eq(true)
        end
      end
    end

    describe "when 2FA is enforced" do
      before { SiteSetting.discourse_connect_url = "https://www.example.com/sso" }

      it "should be invalid" do
        SiteSetting.enforce_second_factor = "all"

        expect(subject.valid_value?("t")).to eq(false)
      end

      it "should be valid" do
        SiteSetting.enforce_second_factor = "no"

        expect(subject.valid_value?("t")).to eq(true)
      end
    end
  end
end
