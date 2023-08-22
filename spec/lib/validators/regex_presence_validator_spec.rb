# frozen_string_literal: true

RSpec.describe RegexPresenceValidator do
  subject(:validator) do
    described_class.new(regex: "latest", regex_error: "site_settings.errors.must_include_latest")
  end

  describe "#valid_value?" do
    describe "when value is present" do
      it "without regex match" do
        expect(validator.valid_value?("categories|new")).to eq(false)

        expect(validator.error_message).to eq(I18n.t("site_settings.errors.must_include_latest"))
      end

      it "with regex match" do
        expect(validator.valid_value?("latest|categories")).to eq(true)
      end
    end

    describe "when value is empty" do
      it "should not be valid" do
        expect(validator.valid_value?("")).to eq(false)

        expect(validator.error_message).to eq(I18n.t("site_settings.errors.must_include_latest"))
      end
    end
  end
end
