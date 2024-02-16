# frozen_string_literal: true

RSpec.describe ThemeSettingsObjectValidator do
  describe "#validate" do
    it "should return the right array of error messages when properties are required but missing" do
      schema = {
        name: "section",
        properties: {
          title: {
            type: "string",
            required: true,
          },
          description: {
            type: "string",
            required: true,
          },
          links: {
            type: "objects",
            schema: {
              name: "link",
              properties: {
                name: {
                  type: "string",
                  required: true,
                },
                child_links: {
                  type: "objects",
                  schema: {
                    name: "child_link",
                    properties: {
                      title: {
                        type: "string",
                        required: true,
                      },
                      not_required: {
                        type: "string",
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }

      errors = described_class.new(schema:, object: {}).validate

      expect(errors).to eq(title: ["must be present"], description: ["must be present"])

      errors =
        described_class.new(
          schema: schema,
          object: {
            links: [{ child_links: [{}, {}] }, {}],
          },
        ).validate

      expect(errors).to eq(
        title: ["must be present"],
        description: ["must be present"],
        links: [
          {
            name: ["must be present"],
            child_links: [{ title: ["must be present"] }, { title: ["must be present"] }],
          },
          { name: ["must be present"] },
        ],
      )
    end
  end
end
