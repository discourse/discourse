# frozen_string_literal: true

RSpec.describe SchemaSettingsObjectValidator do
  def errors_for(schema, object) =
    described_class.new(schema:, object:).validate.transform_values(&:full_messages)

  def schema_with(name, **attributes) = { name: "section", properties: { name => attributes } }

  describe ".property_values_of_type" do
    it "returns an empty array when objects array is empty" do
      schema = { name: "section", properties: { upload: { type: "upload" } } }

      result = described_class.property_values_of_type(schema:, objects: [], type: "upload")

      expect(result).to eq([])
    end

    it "returns the correct array of property values of the specified type" do
      schema = {
        name: "section",
        properties: {
          header_image: {
            type: "upload",
          },
          links: {
            type: "objects",
            schema: {
              name: "link",
              properties: {
                icon: {
                  type: "upload",
                },
                category: {
                  type: "categories",
                },
                related_topic: {
                  type: "topic",
                },
              },
            },
          },
        },
      }

      objects = [
        {
          header_image: 10,
          links: [
            { icon: 20, category: [100, 101], related_topic: 200 },
            { icon: nil, category: [102], related_topic: nil },
          ],
        },
        { header_image: nil, links: [{ icon: 30 }] },
      ]

      expect(
        described_class.property_values_of_type(schema:, objects:, type: "upload"),
      ).to match_array([10, 20, 30])

      expect(
        described_class.property_values_of_type(schema:, objects:, type: "categories"),
      ).to match_array([100, 101, 102])

      expect(
        described_class.property_values_of_type(schema:, objects:, type: "topic"),
      ).to match_array([200])
    end
  end

  describe ".validate_objects" do
    it "returns humanized error messages for invalid objects" do
      schema = {
        name: "section",
        properties: {
          title: {
            type: "string",
            required: true,
            validations: {
              min_length: 5,
              max_length: 10,
            },
          },
          category_property: {
            type: "categories",
            required: true,
          },
          links: {
            type: "objects",
            schema: {
              name: "link",
              properties: {
                position: {
                  type: "integer",
                  required: true,
                },
                float: {
                  type: "float",
                  required: true,
                  validations: {
                    min: 5.5,
                    max: 11.5,
                  },
                },
              },
            },
          },
        },
      }

      category = Fabricate(:category)

      error_messages =
        described_class.validate_objects(
          schema: schema,
          objects: [
            {
              title: "1234",
              category_property: [category.id],
              links: [{ position: 1, float: 4.5 }, { position: "string", float: 12 }],
            },
            { title: "12345678910", category_property: [99_999_999], links: [{ float: 5 }] },
          ],
        )

      expect(error_messages).to eq(
        [
          "The property at JSON Pointer '/0/title' must be at least 5 characters long.",
          "The property at JSON Pointer '/0/links/0/float' must be larger than or equal to 5.5.",
          "The property at JSON Pointer '/0/links/1/position' must be an integer.",
          "The property at JSON Pointer '/0/links/1/float' must be smaller than or equal to 11.5.",
          "The property at JSON Pointer '/1/title' must be at most 10 characters long.",
          "The property at JSON Pointer '/1/category_property' must be an array of valid category ids.",
          "The property at JSON Pointer '/1/links/0/position' must be present.",
          "The property at JSON Pointer '/1/links/0/float' must be larger than or equal to 5.5.",
        ],
      )
    end

    it "looks up the valid ids of each type once for all objects, ignoring malformed values" do
      tag_1 = Fabricate(:tag)
      tag_2 = Fabricate(:tag)
      tag_3 = Fabricate(:tag)

      schema = {
        name: "section",
        properties: {
          links: {
            type: "objects",
            schema: {
              name: "link",
              properties: {
                tags_property: {
                  type: "tags",
                },
              },
            },
          },
          tags_property: {
            type: "tags",
          },
        },
      }

      objects = [
        { tags_property: [tag_1.name], links: [{ tags_property: [tag_2.name] }] },
        { tags_property: [tag_3.name] },
        { tags_property: [{ "name" => tag_1.name }] },
      ]

      queries =
        track_sql_queries do
          expect(described_class.validate_objects(schema:, objects:)).to eq(
            [
              "The property at JSON Pointer '/2/tags_property' must be an array of valid tag names.",
            ],
          )
        end

      expect(queries.length).to eq(1)
    end
  end

  describe "#validate" do
    it "returns errors when required properties are missing or blank" do
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
          category_property: {
            type: "categories",
            required: true,
          },
          enum_property: {
            type: "enum",
            choices: [true, false],
            required: true,
          },
          integer_property: {
            type: "integer",
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

      object = {
        title: "  ",
        description: "",
        category_property: [],
        enum_property: false,
        integer_property: "",
        links: [{ child_links: [{}, {}] }, {}],
      }

      expect(errors_for(schema, object)).to eq(
        "/title" => ["must be present"],
        "/description" => ["must be present"],
        "/category_property" => ["must be present"],
        "/integer_property" => ["must be an integer"],
        "/links/0/name" => ["must be present"],
        "/links/0/child_links/0/title" => ["must be present"],
        "/links/0/child_links/1/title" => ["must be present"],
        "/links/1/name" => ["must be present"],
      )
    end

    it "returns no errors when optional properties are blank" do
      schema = {
        name: "section",
        properties: {
          string_property: {
            type: "string",
            validations: {
              url: true,
            },
          },
          datetime_property: {
            type: "datetime",
          },
          category_property: {
            type: "categories",
            validations: {
              min: 1,
            },
          },
        },
      }

      object = { string_property: "", datetime_property: "", category_property: [] }

      expect(errors_for(schema, object)).to eq({})
    end

    it "returns errors for missing properties of every type only when required" do
      properties =
        %w[string integer float boolean datetime icon upload topic post categories groups tags]
          .index_with { |type| { type: } }
          .merge("enum" => { type: "enum", choices: ["a"] })
      required_properties =
        properties.transform_values { |attributes| attributes.merge(required: true) }

      expect(errors_for({ name: "section", properties: }, {})).to eq({})

      expect(errors_for({ name: "section", properties: required_properties }, {})).to eq(
        properties.keys.to_h { |name| ["/#{name}", ["must be present"]] },
      )
    end

    context "for enum properties" do
      let(:schema) { schema_with(:enum_property, type: "enum", choices: ["choice 1", 2, false]) }

      it "returns no errors when the value is in the enum" do
        expect(errors_for(schema, { enum_property: "choice 1" })).to eq({})
      end

      it "returns errors when the value is not in the enum" do
        expect(errors_for(schema, { enum_property: "random_value" })).to eq(
          "/enum_property" => ["must be one of the following: [\"choice 1\", 2, false]"],
        )
      end
    end

    context "for boolean properties" do
      let(:schema) { schema_with(:boolean_property, type: "boolean", required: true) }

      it "returns no errors when the required boolean is true or false" do
        expect(errors_for(schema, { boolean_property: true })).to eq({})

        expect(errors_for(schema, { boolean_property: false })).to eq({})
      end

      it "returns errors for a non-boolean value" do
        expect(errors_for(schema, { boolean_property: "string" })).to eq(
          "/boolean_property" => ["must be a boolean"],
        )
      end
    end

    context "for float properties" do
      let(:schema) { schema_with(:float_property, type: "float") }

      it "returns no errors for an integer or float value" do
        expect(errors_for(schema, { float_property: 1.5 })).to eq({})

        expect(errors_for(schema, { float_property: 1 })).to eq({})
      end

      it "returns errors for a non-float value" do
        expect(errors_for(schema, { float_property: "string" })).to eq(
          "/float_property" => ["must be a float"],
        )
      end

      it "returns errors when the number fails minimum or maximum validation" do
        schema = schema_with(:float_property, type: "float", validations: { min: 5.5, max: 11.5 })

        expect(errors_for(schema, { float_property: 4.5 })).to eq(
          "/float_property" => ["must be larger than or equal to 5.5"],
        )

        expect(errors_for(schema, { float_property: 12.5 })).to eq(
          "/float_property" => ["must be smaller than or equal to 11.5"],
        )
      end
    end

    context "for integer properties" do
      let(:schema) { schema_with(:integer_property, type: "integer") }

      it "returns no errors for an integer value" do
        expect(errors_for(schema, { integer_property: 1 })).to eq({})
      end

      it "returns errors for a non-integer value" do
        ["string", 1.0].each do |value|
          expect(errors_for(schema, { integer_property: value })).to eq(
            "/integer_property" => ["must be an integer"],
          )
        end
      end

      it "returns errors only when the integer fails range validation" do
        schema = schema_with(:integer_property, type: "integer", validations: { min: 5, max: 10 })

        expect(errors_for(schema, { integer_property: 6 })).to eq({})

        expect(errors_for(schema, { integer_property: 4 })).to eq(
          "/integer_property" => ["must be larger than or equal to 5"],
        )

        expect(errors_for(schema, { integer_property: 11 })).to eq(
          "/integer_property" => ["must be smaller than or equal to 10"],
        )
      end
    end

    context "for string properties" do
      let(:schema) { schema_with(:string_property, type: "string") }

      it "returns no errors for a string value" do
        expect(errors_for(schema, { string_property: "string" })).to eq({})
      end

      it "returns errors for a non-string value" do
        expect(errors_for(schema, { string_property: 1 })).to eq(
          "/string_property" => ["must be a string"],
        )
      end

      it "returns errors only when the string is not a valid URL" do
        schema = schema_with(:string_property, type: "string", validations: { url: true })

        expect(errors_for(schema, { string_property: "https://www.example.com" })).to eq({})

        expect(errors_for(schema, { string_property: "/some-path/to/some-where" })).to eq({})

        expect(errors_for(schema, { string_property: "not a url" })).to eq(
          "/string_property" => ["must be a valid URL"],
        )
      end

      it "returns errors only when the string fails length validation" do
        validations = { min_length: 5, max_length: 10 }
        schema = schema_with(:string_property, type: "string", validations:)

        expect(errors_for(schema, { string_property: "123456" })).to eq({})

        expect(errors_for(schema, { string_property: "1234" })).to eq(
          "/string_property" => ["must be at least 5 characters long"],
        )

        expect(errors_for(schema, { string_property: "12345678910" })).to eq(
          "/string_property" => ["must be at most 10 characters long"],
        )
      end
    end

    context "for topic properties" do
      let(:schema) { schema_with(:topic_property, type: "topic") }

      it "returns no errors for a valid topic ID" do
        topic = Fabricate(:topic)

        expect(errors_for(schema, { topic_property: topic.id })).to eq({})
      end

      it "returns errors for an invalid topic ID" do
        ["string", 99_999_999].each do |value|
          expect(errors_for(schema, { topic_property: value })).to eq(
            "/topic_property" => ["must be a valid topic id"],
          )
        end
      end
    end

    context "for upload properties" do
      let(:schema) do
        {
          name: "section",
          properties: {
            upload_property: {
              type: "upload",
            },
            upload_property_2: {
              type: "upload",
            },
          },
        }
      end

      it "returns no errors for a valid upload URL and ID" do
        upload_1 = Fabricate(:upload)
        upload_2 = Fabricate(:upload)

        object = { upload_property: upload_1.url, upload_property_2: upload_2.id }

        expect(errors_for(schema, object)).to eq({})
      end

      it "returns errors for an invalid upload ID or URL" do
        ["/invalid/upload/url.png", 99_999_999].each do |value|
          expect(errors_for(schema, { upload_property: value })).to eq(
            "/upload_property" => ["must be a valid upload id"],
          )
        end
      end
    end

    context "for tag properties" do
      fab!(:tag_1, :tag)
      fab!(:tag_2, :tag)
      fab!(:tag_3, :tag)

      let(:schema) { schema_with(:tags_property, type: "tags") }

      it "returns no errors for valid tag names" do
        expect(errors_for(schema, { tags_property: [tag_1.name, tag_2.name] })).to eq({})
      end

      it "returns errors for invalid tag names" do
        ["string", ["some random tag name", tag_1.name]].each do |value|
          expect(errors_for(schema, { tags_property: value })).to eq(
            "/tags_property" => ["must be an array of valid tag names"],
          )
        end
      end

      it "returns errors when the tag count fails range validation" do
        schema = schema_with(:tags_property, type: "tags", validations: { min: 2, max: 2 })

        expect(errors_for(schema, { tags_property: [tag_1.name] })).to eq(
          "/tags_property" => ["must have at least 2 tag names"],
        )

        expect(errors_for(schema, { tags_property: [tag_1.name, tag_2.name, tag_3.name] })).to eq(
          "/tags_property" => ["must have at most 2 tag names"],
        )
      end
    end

    context "for groups properties" do
      let(:schema) { schema_with(:groups_property, type: "groups") }

      it "returns no errors for valid group IDs" do
        group = Fabricate(:group)

        expect(errors_for(schema, { groups_property: [group.id] })).to eq({})
      end

      it "returns errors for invalid group IDs" do
        ["string", [99_999_999]].each do |value|
          expect(errors_for(schema, { groups_property: value })).to eq(
            "/groups_property" => ["must be an array of valid group ids"],
          )
        end
      end

      it "returns errors when the group count fails range validation" do
        group_1 = Fabricate(:group)
        group_2 = Fabricate(:group)
        group_3 = Fabricate(:group)

        schema = schema_with(:group_property, type: "groups", validations: { min: 2, max: 2 })

        expect(errors_for(schema, { group_property: [group_1.id] })).to eq(
          "/group_property" => ["must have at least 2 group ids"],
        )

        expect(errors_for(schema, { group_property: [group_1.id, group_2.id, group_3.id] })).to eq(
          "/group_property" => ["must have at most 2 group ids"],
        )
      end
    end

    context "for post properties" do
      let(:schema) { schema_with(:post_property, type: "post") }

      it "returns no errors for a valid post ID" do
        post = Fabricate(:post)

        expect(errors_for(schema, { post_property: post.id })).to eq({})
      end

      it "returns errors for an invalid post ID" do
        ["string", 99_999_999].each do |value|
          expect(errors_for(schema, { post_property: value })).to eq(
            "/post_property" => ["must be a valid post id"],
          )
        end
      end
    end

    context "for categories properties" do
      fab!(:category_1, :category)
      fab!(:category_2, :category)

      let(:schema) { schema_with(:category_property, type: "categories") }

      it "returns no errors for valid category IDs" do
        expect(errors_for(schema, { category_property: [category_1.id, category_2.id] })).to eq({})
      end

      it "returns errors when the category list contains non-integers" do
        expect(errors_for(schema, { category_property: ["string"] })).to eq(
          "/category_property" => ["must be an array of valid category ids"],
        )
      end

      it "returns errors when the category count fails range validation" do
        schema = schema_with(:category_property, type: "categories", validations: { min: 2 })

        expect(errors_for(schema, { category_property: [category_1.id] })).to eq(
          "/category_property" => ["must have at least 2 category ids"],
        )
      end

      it "returns errors when the category list contains invalid IDs" do
        schema = {
          name: "section",
          properties: {
            category_property: {
              type: "categories",
            },
            category_property_2: {
              type: "categories",
            },
            child_categories: {
              type: "objects",
              schema: {
                name: "child_category",
                properties: {
                  category_property_3: {
                    type: "categories",
                  },
                },
              },
            },
          },
        }

        object = {
          category_property: [99_999_999, category_1.id],
          category_property_2: [99_999_999],
          child_categories: [
            { category_property_3: [99_999_999, category_2.id] },
            { category_property_3: [category_2.id] },
          ],
        }

        queries =
          track_sql_queries do
            expect(errors_for(schema, object)).to eq(
              "/category_property" => ["must be an array of valid category ids"],
              "/category_property_2" => ["must be an array of valid category ids"],
              "/child_categories/0/category_property_3" => [
                "must be an array of valid category ids",
              ],
            )
          end

        expect(queries.length).to eq(1)
      end
    end

    context "for datetime properties" do
      let(:schema) { schema_with(:datetime_property, type: "datetime") }

      it "returns no errors for an ISO 8601 datetime with a timezone" do
        %w[2024-12-29T15:30:00Z 2024-12-29T15:30:00.000Z 2024-12-29T15:30:00+05:30].each do |value|
          expect(errors_for(schema, { datetime_property: value })).to eq({})
        end
      end

      it "returns errors for an invalid datetime" do
        ["not a datetime", "2024-12-29", "2024-12-29T15:30:00", 123].each do |value|
          expect(errors_for(schema, { datetime_property: value })).to eq(
            "/datetime_property" => ["must be a valid datetime"],
          )
        end
      end
    end

    context "for icon properties" do
      let(:schema) { schema_with(:icon_property, type: "icon") }

      it "returns no errors for an icon string" do
        expect(errors_for(schema, { icon_property: "heart" })).to eq({})
      end

      it "returns errors for an invalid icon" do
        expect(errors_for(schema, { icon_property: 1 })).to eq(
          "/icon_property" => ["must be an icon name"],
        )
      end
    end
  end
end
