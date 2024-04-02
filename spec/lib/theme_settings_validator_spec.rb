# frozen_string_literal: true

RSpec.describe ThemeSettingsValidator do
  describe ".validate_value" do
    it "does not throw an error when an integer value is given with type `string`" do
      errors = described_class.validate_value(1, ThemeSetting.types[:string], {})

      expect(errors).to eq([])
    end

    it "returns the right error messages when value is invalid for type `objects`" do
      errors =
        described_class.validate_value(
          [{ name: "something" }],
          ThemeSetting.types[:objects],
          {
            schema: {
              name: "test",
              properties: {
                name: {
                  type: "string",
                  validations: {
                    max_length: 1,
                  },
                },
              },
            },
          },
        )

      expect(errors).to contain_exactly(
        "The property at JSON Pointer '/0/name' must be at most 1 character long.",
      )
    end
  end
end
