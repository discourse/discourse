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

  describe ".validate_resolve_group_membership" do
    it "returns error when resolve_group_membership is true on non-list setting" do
      errors =
        described_class.validate_value(
          "test",
          ThemeSetting.types[:string],
          { resolve_group_membership: true },
        )

      expect(errors).to contain_exactly(
        I18n.t("themes.settings_errors.resolve_group_membership_requires_list"),
      )
    end

    it "returns error when resolve_group_membership is true without list_type group" do
      errors =
        described_class.validate_value(
          "a|b|c",
          ThemeSetting.types[:list],
          { resolve_group_membership: true, list_type: "compact" },
        )

      expect(errors).to contain_exactly(
        I18n.t("themes.settings_errors.resolve_group_membership_requires_group_list"),
      )
    end

    it "returns no errors when resolve_group_membership is true with list_type group" do
      errors =
        described_class.validate_value(
          "1|2|3",
          ThemeSetting.types[:list],
          { resolve_group_membership: true, list_type: "group" },
        )

      expect(errors).to eq([])
    end

    it "returns no errors when resolve_group_membership is false" do
      errors =
        described_class.validate_value(
          "test",
          ThemeSetting.types[:string],
          { resolve_group_membership: false },
        )

      expect(errors).to eq([])
    end
  end
end
