# frozen_string_literal: true

RSpec.describe ThemeSettingsValidator do
  describe ".validate_value" do
    it "requires a required string identifier for translatable fields even with no default objects" do
      [nil, { type: "integer", required: true }, { type: "string" }].each do |identifier|
        properties = { title: { type: "string", translatable: true } }
        properties[:translation_key] = identifier if identifier
        errors =
          described_class.validate_value(
            [],
            ThemeSetting.types[:objects],
            schema: {
              name: "card",
              properties: properties,
            },
          )
        expect(errors).to include(
          I18n.t("themes.settings_errors.translatable_requires_translation_key", schema: "card"),
        )
      end
    end

    it "validates nested translatable schemas even when their collections are empty" do
      schema = {
        name: "section",
        properties: {
          translation_key: {
            type: "string",
            required: true,
          },
          cards: {
            type: "objects",
            schema: {
              name: "card",
              properties: {
                title: {
                  type: "string",
                  translatable: true,
                },
              },
            },
          },
        },
      }
      expect(
        described_class.validate_value([], ThemeSetting.types[:objects], schema: schema),
      ).to include(
        I18n.t("themes.settings_errors.translatable_requires_translation_key", schema: "card"),
      )
    end

    it "requires identifiers on ancestors of translatable objects" do
      schema = {
        name: "section",
        properties: {
          cards: {
            type: "objects",
            schema: {
              name: "card",
              properties: {
                translation_key: {
                  type: "string",
                  required: true,
                },
                title: {
                  type: "string",
                  translatable: true,
                },
              },
            },
          },
        },
      }
      expect(
        described_class.validate_value([], ThemeSetting.types[:objects], schema: schema),
      ).to include(
        I18n.t("themes.settings_errors.translatable_requires_translation_key", schema: "section"),
      )
    end

    it "accepts translatable string fields with an identifier and no translations block" do
      schema = {
        name: "card",
        properties: {
          translation_key: {
            type: "string",
            required: true,
          },
          title: {
            type: "string",
            translatable: true,
          },
        },
      }
      expect(
        described_class.validate_value([], ThemeSetting.types[:objects], schema: schema),
      ).to eq([])
    end

    it "does not require an identifier for untranslated objects" do
      schema = { name: "card", properties: { title: { type: "string", translatable: false } } }
      expect(
        described_class.validate_value([], ThemeSetting.types[:objects], schema: schema),
      ).to eq([])
    end

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

    it "returns no errors when resolve_group_membership is true on an object groups property" do
      errors =
        described_class.validate_value(
          [{ groups: [Group::AUTO_GROUPS[:admins]] }],
          ThemeSetting.types[:objects],
          {
            schema: {
              name: "section",
              properties: {
                groups: {
                  type: "groups",
                  resolve_group_membership: true,
                },
              },
            },
          },
        )

      expect(errors).to eq([])
    end

    it "returns an error when resolve_group_membership is true on a non-groups object property" do
      errors =
        described_class.validate_value(
          [{ name: "section", category_ids: [] }],
          ThemeSetting.types[:objects],
          {
            schema: {
              name: "section",
              properties: {
                name: {
                  type: "string",
                  resolve_group_membership: true,
                },
                category_ids: {
                  type: "categories",
                  resolve_group_membership: true,
                },
              },
            },
          },
        )

      expect(errors).to contain_exactly(
        I18n.t(
          "themes.settings_errors.resolve_group_membership_requires_groups_property",
          property: :name,
        ),
        I18n.t(
          "themes.settings_errors.resolve_group_membership_requires_groups_property",
          property: :category_ids,
        ),
      )
    end

    it "returns an error when resolve_group_membership is true on a nested objects property" do
      errors =
        described_class.validate_value(
          [{ links: [] }],
          ThemeSetting.types[:objects],
          {
            schema: {
              name: "section",
              properties: {
                links: {
                  type: "objects",
                  resolve_group_membership: true,
                  schema: {
                    name: "link",
                    properties: {
                      groups: {
                        type: "groups",
                        resolve_group_membership: true,
                      },
                    },
                  },
                },
              },
            },
          },
        )

      expect(errors).to contain_exactly(
        I18n.t(
          "themes.settings_errors.resolve_group_membership_requires_groups_property",
          property: :links,
        ),
      )
    end
  end
end
