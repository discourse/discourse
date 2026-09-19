# frozen_string_literal: true

RSpec.describe SchemaSettingsObjectValidator do
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
  end

  describe "#validate" do
    it "returns errors when required properties are missing" do
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

      expect(errors.keys).to contain_exactly("/description", "/title")
      expect(errors["/description"].full_messages).to contain_exactly("must be present")
      expect(errors["/title"].full_messages).to contain_exactly("must be present")

      errors =
        described_class.new(
          schema: schema,
          object: {
            links: [{ child_links: [{}, {}] }, {}],
          },
        ).validate

      expect(errors.keys).to eq(
        %w[
          /title
          /description
          /links/0/name
          /links/0/child_links/0/title
          /links/0/child_links/1/title
          /links/1/name
        ],
      )

      expect(errors["/title"].full_messages).to contain_exactly("must be present")
      expect(errors["/description"].full_messages).to contain_exactly("must be present")
      expect(errors["/links/0/name"].full_messages).to contain_exactly("must be present")

      expect(errors["/links/0/child_links/0/title"].full_messages).to contain_exactly(
        "must be present",
      )

      expect(errors["/links/0/child_links/1/title"].full_messages).to contain_exactly(
        "must be present",
      )

      expect(errors["/links/1/name"].full_messages).to contain_exactly("must be present")
    end

    context "for enum properties" do
      def schema(required: false)
        property = {
          name: "section",
          properties: {
            enum_property: {
              type: "enum",
              choices: ["choice 1", 2, false],
            },
          },
        }

        property[:properties][:enum_property][:required] = true if required
        property
      end

      it "returns no errors when the value is in the enum" do
        expect(
          described_class.new(schema: schema, object: { enum_property: "choice 1" }).validate,
        ).to eq({})
      end

      it "returns errors when the value is not in the enum" do
        errors =
          described_class.new(schema: schema, object: { enum_property: "random_value" }).validate

        expect(errors.keys).to eq(["/enum_property"])

        expect(errors["/enum_property"].full_messages).to contain_exactly(
          "must be one of the following: [\"choice 1\", 2, false]",
        )
      end

      it "returns no errors when an optional enum property is missing" do
        expect(described_class.new(schema: schema(required: false), object: {}).validate).to eq({})
      end

      it "returns errors when a required enum property is missing" do
        errors = described_class.new(schema: schema(required: true), object: {}).validate

        expect(errors.keys).to eq(["/enum_property"])

        expect(errors["/enum_property"].full_messages).to contain_exactly("must be present")
      end
    end

    context "for boolean properties" do
      let(:schema) { { name: "section", properties: { boolean_property: { type: "boolean" } } } }

      it "returns no errors for a boolean value" do
        expect(
          described_class.new(schema: schema, object: { boolean_property: true }).validate,
        ).to eq({})

        expect(
          described_class.new(schema: schema, object: { boolean_property: false }).validate,
        ).to eq({})
      end

      it "returns errors for a non-boolean value" do
        errors =
          described_class.new(schema: schema, object: { boolean_property: "string" }).validate

        expect(errors.keys).to eq(["/boolean_property"])
        expect(errors["/boolean_property"].full_messages).to contain_exactly("must be a boolean")
      end
    end

    context "for float properties" do
      let(:schema) { { name: "section", properties: { float_property: { type: "float" } } } }

      it "returns no errors for an integer or float value" do
        expect(described_class.new(schema: schema, object: { float_property: 1.5 }).validate).to eq(
          {},
        )

        expect(described_class.new(schema: schema, object: { float_property: 1 }).validate).to eq(
          {},
        )
      end

      it "returns no errors when an optional value is missing" do
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns errors when a required value is missing" do
        schema = {
          name: "section",
          properties: {
            float_property: {
              type: "float",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/float_property"])
        expect(errors["/float_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors for a non-float value" do
        errors = described_class.new(schema: schema, object: { float_property: "string" }).validate

        expect(errors.keys).to eq(["/float_property"])
        expect(errors["/float_property"].full_messages).to contain_exactly("must be a float")
      end

      it "returns errors when the number fails minimum or maximum validation" do
        schema = {
          name: "section",
          properties: {
            float_property: {
              type: "float",
              validations: {
                min: 5.5,
                max: 11.5,
              },
            },
          },
        }

        errors = described_class.new(schema: schema, object: { float_property: 4.5 }).validate

        expect(errors.keys).to eq(["/float_property"])

        expect(errors["/float_property"].full_messages).to contain_exactly(
          "must be larger than or equal to 5.5",
        )

        errors = described_class.new(schema: schema, object: { float_property: 12.5 }).validate

        expect(errors.keys).to eq(["/float_property"])

        expect(errors["/float_property"].full_messages).to contain_exactly(
          "must be smaller than or equal to 11.5",
        )
      end
    end

    context "for integer properties" do
      let(:schema) { { name: "section", properties: { integer_property: { type: "integer" } } } }

      it "returns no errors for an integer value" do
        expect(described_class.new(schema: schema, object: { integer_property: 1 }).validate).to eq(
          {},
        )
      end

      it "returns no errors when the optional integer is missing" do
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns errors when the required integer is missing" do
        schema = {
          name: "section",
          properties: {
            integer_property: {
              type: "integer",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/integer_property"])
        expect(errors["/integer_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors for a non-integer value" do
        errors =
          described_class.new(schema: schema, object: { integer_property: "string" }).validate

        expect(errors.keys).to eq(["/integer_property"])
        expect(errors["/integer_property"].full_messages).to contain_exactly("must be an integer")

        errors = described_class.new(schema: schema, object: { integer_property: 1.0 }).validate

        expect(errors.keys).to eq(["/integer_property"])
        expect(errors["/integer_property"].full_messages).to contain_exactly("must be an integer")
      end

      it "returns no errors when the integer satisfies range validation" do
        schema = {
          name: "section",
          properties: {
            integer_property: {
              type: "integer",
              validations: {
                min: 5,
                max: 10,
              },
            },
          },
        }

        expect(described_class.new(schema: schema, object: { integer_property: 6 }).validate).to eq(
          {},
        )
      end

      it "returns errors when the integer fails range validation" do
        schema = {
          name: "section",
          properties: {
            integer_property: {
              type: "integer",
              validations: {
                min: 5,
                max: 10,
              },
            },
          },
        }

        errors = described_class.new(schema: schema, object: { integer_property: 4 }).validate

        expect(errors.keys).to eq(["/integer_property"])

        expect(errors["/integer_property"].full_messages).to contain_exactly(
          "must be larger than or equal to 5",
        )

        errors = described_class.new(schema: schema, object: { integer_property: 11 }).validate

        expect(errors.keys).to eq(["/integer_property"])

        expect(errors["/integer_property"].full_messages).to contain_exactly(
          "must be smaller than or equal to 10",
        )
      end
    end

    context "for string properties" do
      let(:schema) { { name: "section", properties: { string_property: { type: "string" } } } }

      it "returns no errors for a string value" do
        expect(
          described_class.new(schema: schema, object: { string_property: "string" }).validate,
        ).to eq({})
      end

      it "returns no errors when the optional string is missing" do
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns errors when the required string is missing" do
        schema = {
          name: "section",
          properties: {
            string_property: {
              type: "string",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/string_property"])
        expect(errors["/string_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors for a non-string value" do
        schema = { name: "section", properties: { string_property: { type: "string" } } }
        errors = described_class.new(schema: schema, object: { string_property: 1 }).validate

        expect(errors.keys).to eq(["/string_property"])
        expect(errors["/string_property"].full_messages).to contain_exactly("must be a string")
      end

      it "returns no errors when the string is a valid URL" do
        schema = {
          name: "section",
          properties: {
            string_property: {
              type: "string",
              validations: {
                url: true,
              },
            },
          },
        }

        expect(
          described_class.new(
            schema: schema,
            object: {
              string_property: "https://www.example.com",
            },
          ).validate,
        ).to eq({})

        expect(
          described_class.new(
            schema: schema,
            object: {
              string_property: "/some-path/to/some-where",
            },
          ).validate,
        ).to eq({})
      end

      it "returns errors when the string is not a valid URL" do
        schema = {
          name: "section",
          properties: {
            string_property: {
              type: "string",
              validations: {
                url: true,
              },
            },
          },
        }

        errors =
          described_class.new(schema: schema, object: { string_property: "not a url" }).validate

        expect(errors.keys).to eq(["/string_property"])
        expect(errors["/string_property"].full_messages).to contain_exactly("must be a valid URL")
      end

      it "returns no errors when the string satisfies length validation" do
        schema = {
          name: "section",
          properties: {
            string_property: {
              type: "string",
              validations: {
                min_length: 5,
                max_length: 10,
              },
            },
          },
        }

        expect(
          described_class.new(schema: schema, object: { string_property: "123456" }).validate,
        ).to eq({})
      end

      it "returns errors when the string fails length validation" do
        schema = {
          name: "section",
          properties: {
            string_property: {
              type: "string",
              validations: {
                min_length: 5,
                max_length: 10,
              },
            },
          },
        }

        errors = described_class.new(schema: schema, object: { string_property: "1234" }).validate

        expect(errors.keys).to eq(["/string_property"])

        expect(errors["/string_property"].full_messages).to contain_exactly(
          "must be at least 5 characters long",
        )

        errors =
          described_class.new(schema: schema, object: { string_property: "12345678910" }).validate

        expect(errors.keys).to eq(["/string_property"])

        expect(errors["/string_property"].full_messages).to contain_exactly(
          "must be at most 10 characters long",
        )
      end
    end

    context "for topic properties" do
      it "returns no errors for a valid topic ID" do
        topic = Fabricate(:topic)

        schema = { name: "section", properties: { topic_property: { type: "topic" } } }

        expect(
          described_class.new(schema: schema, object: { topic_property: topic.id }).validate,
        ).to eq({})
      end

      it "returns no errors when the optional topic ID is missing" do
        schema = { name: "section", properties: { topic_property: { type: "topic" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns errors when the required topic ID is missing" do
        schema = {
          name: "section",
          properties: {
            topic_property: {
              type: "topic",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/topic_property"])
        expect(errors["/topic_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors when the topic ID is not an integer" do
        schema = { name: "section", properties: { topic_property: { type: "topic" } } }

        errors = described_class.new(schema: schema, object: { topic_property: "string" }).validate

        expect(errors.keys).to eq(["/topic_property"])

        expect(errors["/topic_property"].full_messages).to contain_exactly(
          "must be a valid topic id",
        )
      end

      it "returns errors for an unknown topic ID" do
        schema = {
          name: "section",
          properties: {
            topic_property: {
              type: "topic",
            },
            child_topics: {
              type: "objects",
              schema: {
                name: "child_topic",
                properties: {
                  topic_property_2: {
                    type: "topic",
                  },
                },
              },
            },
          },
        }

        queries =
          track_sql_queries do
            errors =
              described_class.new(
                schema:,
                object: {
                  topic_property: 99_999_999,
                  child_topics: [{ topic_property_2: 99_999_999 }],
                },
              ).validate

            expect(errors.keys).to eq(%w[/topic_property /child_topics/0/topic_property_2])

            expect(errors["/topic_property"].full_messages).to contain_exactly(
              "must be a valid topic id",
            )

            expect(errors["/child_topics/0/topic_property_2"].full_messages).to contain_exactly(
              "must be a valid topic id",
            )
          end

        # only 1 SQL query should be executed to check if topic ids are valid
        expect(queries.length).to eq(1)
      end
    end

    context "for upload properties" do
      it "returns no errors for a valid upload ID" do
        upload = Fabricate(:upload)

        schema = { name: "section", properties: { upload_property: { type: "upload" } } }

        expect(
          described_class.new(schema: schema, object: { upload_property: upload.id }).validate,
        ).to eq({})
      end

      it "returns no errors when the optional upload ID is missing" do
        schema = { name: "section", properties: { upload_property: { type: "upload" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns errors when the required upload ID is missing" do
        schema = {
          name: "section",
          properties: {
            upload_property: {
              type: "upload",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/upload_property"])
        expect(errors["/upload_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors when the upload ID is not an integer" do
        schema = { name: "section", properties: { upload_property: { type: "upload" } } }

        errors = described_class.new(schema: schema, object: { upload_property: "string" }).validate

        expect(errors.keys).to eq(["/upload_property"])

        expect(errors["/upload_property"].full_messages).to contain_exactly(
          "must be a valid upload id",
        )
      end

      it "returns errors when the upload value is an invalid URL" do
        schema = { name: "section", properties: { upload_property: { type: "upload" } } }

        errors =
          described_class.new(
            schema: schema,
            object: {
              upload_property: "/invalid/upload/url.png",
            },
          ).validate

        expect(errors.keys).to eq(["/upload_property"])

        expect(errors["/upload_property"].full_messages).to contain_exactly(
          "must be a valid upload id",
        )
      end

      it "returns errors for an unknown upload ID" do
        schema = {
          name: "section",
          properties: {
            upload_property: {
              type: "upload",
            },
            child_uploads: {
              type: "objects",
              schema: {
                name: "child_upload",
                properties: {
                  upload_property_2: {
                    type: "upload",
                  },
                },
              },
            },
          },
        }

        queries =
          track_sql_queries do
            errors =
              described_class.new(
                schema:,
                object: {
                  upload_property: 99_999_999,
                  child_uploads: [{ upload_property_2: 99_999_999 }],
                },
              ).validate

            expect(errors.keys).to eq(%w[/upload_property /child_uploads/0/upload_property_2])

            expect(errors["/upload_property"].full_messages).to contain_exactly(
              "must be a valid upload id",
            )

            expect(errors["/child_uploads/0/upload_property_2"].full_messages).to contain_exactly(
              "must be a valid upload id",
            )
          end

        # only 1 SQL query should be executed to check if upload ids are valid
        expect(queries.length).to eq(1)
      end
    end

    context "for tag properties" do
      fab!(:tag_1, :tag)
      fab!(:tag_2, :tag)
      fab!(:tag_3, :tag)

      it "returns no errors for valid tag names" do
        schema = { name: "section", properties: { tags_property: { type: "tags" } } }

        expect(
          described_class.new(
            schema: schema,
            object: {
              tags_property: [tag_1.name, tag_2.name],
            },
          ).validate,
        ).to eq({})
      end

      it "returns no errors when the optional tag list is missing" do
        schema = { name: "section", properties: { tags_property: { type: "tags" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns errors when the required tag list is missing" do
        schema = {
          name: "section",
          properties: {
            tags_property: {
              type: "tags",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/tags_property"])
        expect(errors["/tags_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors when the tag value is not an array" do
        schema = { name: "section", properties: { tags_property: { type: "tags" } } }

        errors = described_class.new(schema: schema, object: { tags_property: "string" }).validate

        expect(errors.keys).to eq(["/tags_property"])

        expect(errors["/tags_property"].full_messages).to contain_exactly(
          "must be an array of valid tag names",
        )
      end

      it "returns errors when the tag count fails range validation" do
        schema = {
          name: "section",
          properties: {
            tags_property: {
              type: "tags",
              validations: {
                min: 1,
                max: 2,
              },
            },
          },
        }

        errors = described_class.new(schema: schema, object: { tags_property: [] }).validate

        expect(errors.keys).to eq(["/tags_property"])

        expect(errors["/tags_property"].full_messages).to contain_exactly(
          "must have at least 1 tag name",
        )

        errors =
          described_class.new(
            schema: schema,
            object: {
              tags_property: [tag_1.name, tag_2.name, tag_3.name],
            },
          ).validate

        expect(errors.keys).to eq(["/tags_property"])

        expect(errors["/tags_property"].full_messages).to contain_exactly(
          "must have at most 2 tag names",
        )
      end

      it "returns errors when the list contains invalid tag names" do
        schema = {
          name: "section",
          properties: {
            tags_property: {
              type: "tags",
            },
            child_tags: {
              type: "objects",
              schema: {
                name: "child_tag",
                properties: {
                  tags_property_2: {
                    type: "tags",
                  },
                },
              },
            },
          },
        }

        tag_1

        queries =
          track_sql_queries do
            errors =
              described_class.new(
                schema:,
                object: {
                  tags_property: ["some random tag name", tag_1.name],
                  child_tags: [{ tags_property_2: ["some random tag name", tag_1.name, "abcdef"] }],
                },
              ).validate

            expect(errors.keys).to eq(%w[/tags_property /child_tags/0/tags_property_2])

            expect(errors["/tags_property"].full_messages).to contain_exactly(
              "must be an array of valid tag names",
            )

            expect(errors["/child_tags/0/tags_property_2"].full_messages).to contain_exactly(
              "must be an array of valid tag names",
            )
          end

        # only 1 SQL query should be executed to check if tag ids are valid
        expect(queries.length).to eq(1)
      end
    end

    context "for groups properties" do
      it "returns no errors for valid group IDs" do
        group = Fabricate(:group)

        schema = { name: "section", properties: { groups_property: { type: "groups" } } }

        expect(
          described_class.new(schema: schema, object: { groups_property: [group.id] }).validate,
        ).to eq({})
      end

      it "returns no errors when the optional group list is missing" do
        schema = { name: "section", properties: { groups_property: { type: "groups" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns errors when the required group list is missing" do
        schema = {
          name: "section",
          properties: {
            groups_property: {
              type: "groups",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/groups_property"])
        expect(errors["/groups_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors when the group value is not an array of valid IDs" do
        schema = { name: "section", properties: { groups_property: { type: "groups" } } }

        errors = described_class.new(schema: schema, object: { groups_property: "string" }).validate

        expect(errors.keys).to eq(["/groups_property"])

        expect(errors["/groups_property"].full_messages).to contain_exactly(
          "must be an array of valid group ids",
        )
      end

      it "returns errors when the group count fails range validation" do
        group_1 = Fabricate(:group)
        group_2 = Fabricate(:group)
        group_3 = Fabricate(:group)

        schema = {
          name: "section",
          properties: {
            group_property: {
              type: "groups",
              validations: {
                min: 1,
                max: 2,
              },
            },
          },
        }

        errors = described_class.new(schema: schema, object: { group_property: [] }).validate

        expect(errors.keys).to eq(["/group_property"])

        expect(errors["/group_property"].full_messages).to contain_exactly(
          "must have at least 1 group id",
        )

        errors =
          described_class.new(
            schema: schema,
            object: {
              group_property: [group_1.id, group_2.id, group_3.id],
            },
          ).validate

        expect(errors.keys).to eq(["/group_property"])

        expect(errors["/group_property"].full_messages).to contain_exactly(
          "must have at most 2 group ids",
        )
      end

      it "returns errors when the list contains invalid group IDs" do
        schema = {
          name: "section",
          properties: {
            groups_property: {
              type: "groups",
            },
            child_groups: {
              type: "objects",
              schema: {
                name: "child_group",
                properties: {
                  groups_property_2: {
                    type: "groups",
                  },
                },
              },
            },
          },
        }

        queries =
          track_sql_queries do
            errors =
              described_class.new(
                schema:,
                object: {
                  groups_property: [99_999_999],
                  child_groups: [{ groups_property_2: [99_999_999] }],
                },
              ).validate

            expect(errors.keys).to eq(%w[/groups_property /child_groups/0/groups_property_2])

            expect(errors["/groups_property"].full_messages).to contain_exactly(
              "must be an array of valid group ids",
            )

            expect(errors["/child_groups/0/groups_property_2"].full_messages).to contain_exactly(
              "must be an array of valid group ids",
            )
          end

        # only 1 SQL query should be executed to check if group ids are valid
        expect(queries.length).to eq(1)
      end
    end

    context "for post properties" do
      it "returns no errors for a valid post ID" do
        post = Fabricate(:post)

        schema = { name: "section", properties: { post_property: { type: "post" } } }

        expect(
          described_class.new(schema: schema, object: { post_property: post.id }).validate,
        ).to eq({})
      end

      it "returns no errors when the optional post ID is missing" do
        schema = { name: "section", properties: { post_property: { type: "post" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns errors when the required post ID is missing" do
        schema = {
          name: "section",
          properties: {
            post_property: {
              type: "post",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/post_property"])
        expect(errors["/post_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors when the post ID is not an integer" do
        schema = { name: "section", properties: { post_property: { type: "post" } } }

        errors = described_class.new(schema: schema, object: { post_property: "string" }).validate

        expect(errors.keys).to eq(["/post_property"])

        expect(errors["/post_property"].full_messages).to contain_exactly("must be a valid post id")
      end

      it "returns errors for an unknown post ID" do
        schema = {
          name: "section",
          properties: {
            post_property: {
              type: "post",
            },
            child_posts: {
              type: "objects",
              schema: {
                name: "child_post",
                properties: {
                  post_property_2: {
                    type: "post",
                  },
                },
              },
            },
          },
        }

        queries =
          track_sql_queries do
            errors =
              described_class.new(
                schema:,
                object: {
                  post_property: 99_999_999,
                  child_posts: [{ post_property_2: 99_999_999 }],
                },
              ).validate

            expect(errors.keys).to eq(%w[/post_property /child_posts/0/post_property_2])

            expect(errors["/post_property"].full_messages).to contain_exactly(
              "must be a valid post id",
            )

            expect(errors["/child_posts/0/post_property_2"].full_messages).to contain_exactly(
              "must be a valid post id",
            )
          end

        # only 1 SQL query should be executed to check if post ids are valid
        expect(queries.length).to eq(1)
      end
    end

    context "for categories properties" do
      fab!(:category_1, :category)
      fab!(:category_2, :category)

      it "returns no errors for valid category IDs" do
        schema = { name: "section", properties: { category_property: { type: "categories" } } }

        expect(
          described_class.new(
            schema: schema,
            object: {
              category_property: [category_1.id, category_2.id],
            },
          ).validate,
        ).to eq({})
      end

      it "returns no errors when the optional category list is missing" do
        schema = { name: "section", properties: { category_property: { type: "categories" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns errors when the required category list is empty" do
        schema = {
          name: "section",
          properties: {
            category_property: {
              type: "categories",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: { category_property: [] }).validate

        expect(errors.keys).to eq(["/category_property"])
        expect(errors["/category_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors when the required category list is missing" do
        schema = {
          name: "section",
          properties: {
            category_property: {
              type: "categories",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/category_property"])
        expect(errors["/category_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors when the category list contains non-integers" do
        schema = { name: "section", properties: { category_property: { type: "categories" } } }

        errors =
          described_class.new(schema: schema, object: { category_property: ["string"] }).validate

        expect(errors.keys).to eq(["/category_property"])

        expect(errors["/category_property"].full_messages).to contain_exactly(
          "must be an array of valid category ids",
        )
      end

      it "returns errors when the category count fails range validation" do
        schema = {
          name: "section",
          properties: {
            category_property: {
              type: "categories",
              validations: {
                min: 1,
                max: 2,
              },
            },
          },
        }

        errors = described_class.new(schema: schema, object: { category_property: [] }).validate

        expect(errors.keys).to eq(["/category_property"])

        expect(errors["/category_property"].full_messages).to contain_exactly(
          "must have at least 1 category id",
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
            errors = described_class.new(schema:, object:).validate

            expect(errors.keys).to eq(
              %w[/category_property /category_property_2 /child_categories/0/category_property_3],
            )

            expect(errors["/category_property"].full_messages).to contain_exactly(
              "must be an array of valid category ids",
            )

            expect(errors["/category_property_2"].full_messages).to contain_exactly(
              "must be an array of valid category ids",
            )

            expect(
              errors["/child_categories/0/category_property_3"].full_messages,
            ).to contain_exactly("must be an array of valid category ids")
          end

        # only 1 SQL query should be executed to check if category ids are valid
        expect(queries.length).to eq(1)
      end
    end

    context "for datetime properties" do
      let(:schema) { { name: "section", properties: { datetime_property: { type: "datetime" } } } }

      it "returns no errors for a valid UTC datetime" do
        expect(
          described_class.new(
            schema: schema,
            object: {
              datetime_property: "2024-12-29T15:30:00Z",
            },
          ).validate,
        ).to eq({})

        expect(
          described_class.new(
            schema: schema,
            object: {
              datetime_property: "2024-12-29T15:30:00.000Z",
            },
          ).validate,
        ).to eq({})
      end

      it "returns no errors for an ISO 8601 datetime with a timezone offset" do
        expect(
          described_class.new(
            schema: schema,
            object: {
              datetime_property: "2024-12-29T15:30:00+05:30",
            },
          ).validate,
        ).to eq({})
      end

      it "returns no errors when the optional datetime is missing" do
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns no errors when the optional datetime is blank" do
        expect(
          described_class.new(schema: schema, object: { datetime_property: "" }).validate,
        ).to eq({})
      end

      it "returns errors when the required datetime is missing" do
        schema = {
          name: "section",
          properties: {
            datetime_property: {
              type: "datetime",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/datetime_property"])
        expect(errors["/datetime_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors for an invalid datetime" do
        errors =
          described_class.new(
            schema: schema,
            object: {
              datetime_property: "not a datetime",
            },
          ).validate

        expect(errors.keys).to eq(["/datetime_property"])
        expect(errors["/datetime_property"].full_messages).to contain_exactly(
          "must be a valid datetime",
        )
      end

      it "returns errors for a date-only string" do
        errors =
          described_class.new(schema: schema, object: { datetime_property: "2024-12-29" }).validate

        expect(errors.keys).to eq(["/datetime_property"])
        expect(errors["/datetime_property"].full_messages).to contain_exactly(
          "must be a valid datetime",
        )
      end

      it "returns errors for a datetime without a timezone" do
        errors =
          described_class.new(
            schema: schema,
            object: {
              datetime_property: "2024-12-29T15:30:00",
            },
          ).validate

        expect(errors.keys).to eq(["/datetime_property"])
        expect(errors["/datetime_property"].full_messages).to contain_exactly(
          "must be a valid datetime",
        )
      end

      it "returns errors when the datetime is not a string" do
        errors = described_class.new(schema: schema, object: { datetime_property: 123 }).validate

        expect(errors.keys).to eq(["/datetime_property"])
        expect(errors["/datetime_property"].full_messages).to contain_exactly(
          "must be a valid datetime",
        )
      end
    end

    context "for icon properties" do
      let(:schema) { { name: "section", properties: { icon_property: { type: "icon" } } } }

      it "returns no errors for an icon string" do
        expect(
          described_class.new(schema: schema, object: { icon_property: "heart" }).validate,
        ).to eq({})
      end

      it "returns no errors when the optional icon is missing" do
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "returns errors when the required icon is missing" do
        schema = {
          name: "section",
          properties: {
            icon_property: {
              type: "icon",
              required: true,
            },
          },
        }
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors.keys).to eq(["/icon_property"])
        expect(errors["/icon_property"].full_messages).to contain_exactly("must be present")
      end

      it "returns errors for an invalid icon" do
        errors = described_class.new(schema: schema, object: { icon_property: 1 }).validate

        expect(errors.keys).to eq(["/icon_property"])
        expect(errors["/icon_property"].full_messages).to contain_exactly("must be an icon name")
      end
    end
  end
end
