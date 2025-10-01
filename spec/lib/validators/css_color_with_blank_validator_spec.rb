# frozen_string_literal: true

RSpec.describe CssColorWithBlankValidator do
  subject(:validator) { described_class.new }

  describe "#valid_value?" do
    context "when value is blank" do
      it "accepts nil values" do
        expect(validator.valid_value?(nil)).to eq(true)
      end

      it "accepts empty strings" do
        expect(validator.valid_value?("")).to eq(true)
      end

      it "accepts strings with only whitespace" do
        expect(validator.valid_value?("  ")).to eq(true)
        expect(validator.valid_value?("\t")).to eq(true)
        expect(validator.valid_value?("\n")).to eq(true)
        expect(validator.valid_value?("   \t \n ")).to eq(true)
      end
    end

    context "when inherits parent validation behavior" do
      it "still validates valid colors" do
        expect(validator.valid_value?("#fde")).to eq(true)
        expect(validator.valid_value?("#000000")).to eq(true)
        expect(validator.valid_value?("red")).to eq(true)
      end

      it "still rejects invalid colors" do
        expect(validator.valid_value?("#g")).to eq(false)
        expect(validator.valid_value?("invalidcolor")).to eq(false)
      end
    end
  end

  describe "#error_message" do
    it "returns the correct internationalization key" do
      expect(validator.error_message).to eq(I18n.t("site_settings.errors.invalid_css_color"))
    end
  end
end
