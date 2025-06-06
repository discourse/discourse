# frozen_string_literal: true

RSpec.describe SchemaSettingsObjectValidator do
  describe ".validate_objects" do
    it "should return the right array of humanized error messages for objects that are invalid" do
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
    it "should return the right hash of error messages when properties are required but missing" do
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

      it "should not return any error messages when the value of the property is in the enum" do
        expect(
          described_class.new(schema: schema, object: { enum_property: "choice 1" }).validate,
        ).to eq({})
      end

      it "should return the right hash of error messages when value of property is not in the enum" do
        errors =
          described_class.new(schema: schema, object: { enum_property: "random_value" }).validate

        expect(errors.keys).to eq(["/enum_property"])

        expect(errors["/enum_property"].full_messages).to contain_exactly(
          "must be one of the following: [\"choice 1\", 2, false]",
        )
      end

      it "should not return any error messages when enum property is not present but is not required" do
        expect(described_class.new(schema: schema(required: false), object: {}).validate).to eq({})
      end

      it "should return the right hash of error messages when enum property is not present and is required" do
        errors = described_class.new(schema: schema(required: true), object: {}).validate

        expect(errors.keys).to eq(["/enum_property"])

        expect(errors["/enum_property"].full_messages).to contain_exactly("must be present")
      end
    end

    context "for boolean properties" do
      let(:schema) { { name: "section", properties: { boolean_property: { type: "boolean" } } } }

      it "should not return any error messages when the value of the property is of type boolean" do
        expect(
          described_class.new(schema: schema, object: { boolean_property: true }).validate,
        ).to eq({})

        expect(
          described_class.new(schema: schema, object: { boolean_property: false }).validate,
        ).to eq({})
      end

      it "should return the right hash of error messages when value of property is not of type boolean" do
        errors =
          described_class.new(schema: schema, object: { boolean_property: "string" }).validate

        expect(errors.keys).to eq(["/boolean_property"])
        expect(errors["/boolean_property"].full_messages).to contain_exactly("must be a boolean")
      end
    end

    context "for float properties" do
      let(:schema) { { name: "section", properties: { float_property: { type: "float" } } } }

      it "should not return any error messages when the value of the property is of type integer or float" do
        expect(described_class.new(schema: schema, object: { float_property: 1.5 }).validate).to eq(
          {},
        )

        expect(described_class.new(schema: schema, object: { float_property: 1 }).validate).to eq(
          {},
        )
      end

      it "should not return any error messages when the value is not present and it's not required in the schema" do
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "should return the right hash of error messages when value of property is not present and it's required" do
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

      it "should return the right hash of error messages when value of property is not of type float" do
        errors = described_class.new(schema: schema, object: { float_property: "string" }).validate

        expect(errors.keys).to eq(["/float_property"])
        expect(errors["/float_property"].full_messages).to contain_exactly("must be a float")
      end

      it "should return the right hash of error messages when integer property does not satisfy min or max validations" do
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

      it "should not return any error messages when the value of the property is of type integer" do
        expect(described_class.new(schema: schema, object: { integer_property: 1 }).validate).to eq(
          {},
        )
      end

      it "should not return any error messages when the value is not present and it's not required in the schema" do
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "should return the right hash of error messages when value of property is not present and it's required" do
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

      it "should return the right hash of error messages when value of property is not of type integer" do
        errors =
          described_class.new(schema: schema, object: { integer_property: "string" }).validate

        expect(errors.keys).to eq(["/integer_property"])
        expect(errors["/integer_property"].full_messages).to contain_exactly("must be an integer")

        errors = described_class.new(schema: schema, object: { integer_property: 1.0 }).validate

        expect(errors.keys).to eq(["/integer_property"])
        expect(errors["/integer_property"].full_messages).to contain_exactly("must be an integer")
      end

      it "should not return any error messages when the value of the integer property satisfies min and max validations" do
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

      it "should return the right hash of error messages when integer property does not satisfy min or max validations" do
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

      it "should not return any error messages when the value of the property is of type string" do
        expect(
          described_class.new(schema: schema, object: { string_property: "string" }).validate,
        ).to eq({})
      end

      it "should not return any error messages when the value is not present and it's not required in the schema" do
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "should return the right hash of error messages when value of property is not present and it's required" do
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

      it "should return the right hash of error messages when value of property is not of type string" do
        schema = { name: "section", properties: { string_property: { type: "string" } } }
        errors = described_class.new(schema: schema, object: { string_property: 1 }).validate

        expect(errors.keys).to eq(["/string_property"])
        expect(errors["/string_property"].full_messages).to contain_exactly("must be a string")
      end

      it "should not return an empty hash when string property satisfy url validation" do
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

      it "should return the right hash of error messages when string property does not statisfy url validation" do
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

      it "should not return any error messages when the value of the string property satisfies min_length and max_length validations" do
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

      it "should return the right hash of error messages when string property does not satisfy min_length or max_length validations" do
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
      it "should not return any error message when the value of the property is a valid id of a topic record" do
        topic = Fabricate(:topic)

        schema = { name: "section", properties: { topic_property: { type: "topic" } } }

        expect(
          described_class.new(schema: schema, object: { topic_property: topic.id }).validate,
        ).to eq({})
      end

      it "should not return any error messages when the value is not present and it's not required in the schema" do
        schema = { name: "section", properties: { topic_property: { type: "topic" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "should return the right hash of error messages when value of property is not present and it's required" do
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

      it "should return the right hash of error messages when value of property is not an integer" do
        schema = { name: "section", properties: { topic_property: { type: "topic" } } }

        errors = described_class.new(schema: schema, object: { topic_property: "string" }).validate

        expect(errors.keys).to eq(["/topic_property"])

        expect(errors["/topic_property"].full_messages).to contain_exactly(
          "must be a valid topic id",
        )
      end

      it "should return the right hash of error messages when value of property is not a valid id of a topic record" do
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
      it "should not return any error message when the value of the property is a valid id of a upload record" do
        upload = Fabricate(:upload)

        schema = { name: "section", properties: { upload_property: { type: "upload" } } }

        expect(
          described_class.new(schema: schema, object: { upload_property: upload.id }).validate,
        ).to eq({})
      end

      it "should not return any error messages when the value is not present and it's not required in the schema" do
        schema = { name: "section", properties: { upload_property: { type: "upload" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "should return the right hash of error messages when value of property is not present and it's required" do
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

      it "should return the right hash of error messages when value of property is not an integer" do
        schema = { name: "section", properties: { upload_property: { type: "upload" } } }

        errors = described_class.new(schema: schema, object: { upload_property: "string" }).validate

        expect(errors.keys).to eq(["/upload_property"])

        expect(errors["/upload_property"].full_messages).to contain_exactly(
          "must be a valid upload id",
        )
      end

      it "should return the right hash of error messages when value of property is not a valid id of a upload record" do
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
      fab!(:tag_1) { Fabricate(:tag) }
      fab!(:tag_2) { Fabricate(:tag) }
      fab!(:tag_3) { Fabricate(:tag) }

      it "should not return any error message when the value of the property is an array of valid tag names" do
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

      it "should not return any error messages when the value is not present and it's not required in the schema" do
        schema = { name: "section", properties: { tags_property: { type: "tags" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "should return the right hash of error messages when value of property is not present and it's required" do
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

      it "should return the right hash of error messages when value of property is not an array of tag names" do
        schema = { name: "section", properties: { tags_property: { type: "tags" } } }

        errors = described_class.new(schema: schema, object: { tags_property: "string" }).validate

        expect(errors.keys).to eq(["/tags_property"])

        expect(errors["/tags_property"].full_messages).to contain_exactly(
          "must be an array of valid tag names",
        )
      end

      it "should return the right hash of error messages when number of tag names does not satisfy min or max validations" do
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

      it "should return the right hash of error messages when value of property contain tag names which are invalid" do
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
      it "should not return any error message when the value of the property is an array of valid group record ids" do
        group = Fabricate(:group)

        schema = { name: "section", properties: { groups_property: { type: "groups" } } }

        expect(
          described_class.new(schema: schema, object: { groups_property: [group.id] }).validate,
        ).to eq({})
      end

      it "should not return any error messages when the value is not present and it's not required in the schema" do
        schema = { name: "section", properties: { groups_property: { type: "groups" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "should return the right hash of error messages when value of property is not present and it's required" do
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

      it "should return the right hash of error messages when value of property is not an array of valid group ids" do
        schema = { name: "section", properties: { groups_property: { type: "groups" } } }

        errors = described_class.new(schema: schema, object: { groups_property: "string" }).validate

        expect(errors.keys).to eq(["/groups_property"])

        expect(errors["/groups_property"].full_messages).to contain_exactly(
          "must be an array of valid group ids",
        )
      end

      it "should return the right hash of error messages when number of groups ids does not satisfy min or max validations" do
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

      it "should return the right hash of error messages when value of property is an array containing invalid group ids" do
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
      it "should not return any error message when the value of the property is a valid id of a post record" do
        post = Fabricate(:post)

        schema = { name: "section", properties: { post_property: { type: "post" } } }

        expect(
          described_class.new(schema: schema, object: { post_property: post.id }).validate,
        ).to eq({})
      end

      it "should not return any error messages when the value is not present and it's not required in the schema" do
        schema = { name: "section", properties: { post_property: { type: "post" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "should return the right hash of error messages when value of property is not present and it's required" do
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

      it "should return the right hash of error messages when value of property is not an integer" do
        schema = { name: "section", properties: { post_property: { type: "post" } } }

        errors = described_class.new(schema: schema, object: { post_property: "string" }).validate

        expect(errors.keys).to eq(["/post_property"])

        expect(errors["/post_property"].full_messages).to contain_exactly("must be a valid post id")
      end

      it "should return the right hash of error messages when value of property is not a valid id of a post record" do
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
      fab!(:category_1) { Fabricate(:category) }
      fab!(:category_2) { Fabricate(:category) }

      it "should not return any error message when the value of the property is an array of valid category ids" do
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

      it "should not return any error messages when the value is not present and it's not required in the schema" do
        schema = { name: "section", properties: { category_property: { type: "categories" } } }
        expect(described_class.new(schema: schema, object: {}).validate).to eq({})
      end

      it "should return the right hash of error messages when value of property is present but empty and it's required" do
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

      it "should return the right hash of error messages when value of property is not present and it's required" do
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

      it "should return the right hash of error messages when value of property contains an array where not all values are integers" do
        schema = { name: "section", properties: { category_property: { type: "categories" } } }

        errors =
          described_class.new(schema: schema, object: { category_property: ["string"] }).validate

        expect(errors.keys).to eq(["/category_property"])

        expect(errors["/category_property"].full_messages).to contain_exactly(
          "must be an array of valid category ids",
        )
      end

      it "should return the right hash of error messages when number of category ids does not satisfy min or max validations" do
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

      it "should return the right hash of error messages when value of property is not an array of valid category ids" do
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
  end
end
