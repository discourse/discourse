# frozen_string_literal: true

RSpec.describe I18nInterpolationKeysFinder do
  describe "#find" do
    it "should return the right keys" do
      expect(described_class.find("%{first} %{second} {{third}}")).to eq(%w[first second third])
    end
  end
end
