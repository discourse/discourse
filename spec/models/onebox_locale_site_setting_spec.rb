# frozen_string_literal: true

RSpec.describe OneboxLocaleSiteSetting do
  describe ".valid_value?" do
    it "returns true for a locale that we have translations for" do
      expect(OneboxLocaleSiteSetting.valid_value?("en")).to eq(true)
    end

    it "returns true for an empty value" do
      expect(OneboxLocaleSiteSetting.valid_value?("")).to eq(true)
    end

    it "returns false for a locale that we do not have translations for" do
      expect(OneboxLocaleSiteSetting.valid_value?("swedish-chef")).to eq(false)
    end
  end
end
