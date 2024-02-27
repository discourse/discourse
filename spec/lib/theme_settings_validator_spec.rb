# frozen_string_literal: true

RSpec.describe ThemeSettingsValidator do
  describe ".validate_value" do
    it "does not throw an error when an integer value is given with type `string`" do
      errors = described_class.validate_value(1, ThemeSetting.types[:string], {})

      expect(errors).to eq([])
    end
  end
end
