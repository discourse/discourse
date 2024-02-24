# frozen_string_literal: true

RSpec.describe ThemeSettingsObjectValidator do
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

      expect(errors[:description].full_messages).to contain_exactly("must be present")
      expect(errors[:title].full_messages).to contain_exactly("must be present")

      errors =
        described_class.new(
          schema: schema,
          object: {
            links: [{ child_links: [{}, {}] }, {}],
          },
        ).validate

      expect(errors[:title].full_messages).to contain_exactly("must be present")
      expect(errors[:description].full_messages).to contain_exactly("must be present")
      expect(errors[:links][0][:name].full_messages).to contain_exactly("must be present")

      expect(errors[:links][0][:child_links][0][:title].full_messages).to contain_exactly(
        "must be present",
      )

      expect(errors[:links][0][:child_links][1][:title].full_messages).to contain_exactly(
        "must be present",
      )

      expect(errors[:links][1][:name].full_messages).to contain_exactly("must be present")
    end

    context "for enum properties" do
      let(:schema) do
        {
          name: "section",
          properties: {
            enum_property: {
              type: "enum",
              choices: ["choice 1", 2, false],
            },
          },
        }
      end

      it "should not return any error messages when the value of the property is in the enum" do
        expect(
          described_class.new(schema: schema, object: { enum_property: "choice 1" }).validate,
        ).to eq({})
      end

      it "should return the right hash of error messages when value of property is not in the enum" do
        errors =
          described_class.new(schema: schema, object: { enum_property: "random_value" }).validate

        expect(errors[:enum_property].full_messages).to contain_exactly(
          "must be one of the following: [\"choice 1\", 2, false]",
        )
      end

      it "should return the right hash of error messages when enum property is not present" do
        errors = described_class.new(schema: schema, object: {}).validate

        expect(errors[:enum_property].full_messages).to contain_exactly(
          "must be one of the following: [\"choice 1\", 2, false]",
        )
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

        expect(errors[:boolean_property].full_messages).to contain_exactly("must be a boolean")
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

      it "should return the right hash of error messages when value of property is not of type float" do
        errors = described_class.new(schema: schema, object: { float_property: "string" }).validate

        expect(errors[:float_property].full_messages).to contain_exactly("must be a float")
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

        expect(errors[:float_property].full_messages).to contain_exactly(
          "must be larger than or equal to 5.5",
        )

        errors = described_class.new(schema: schema, object: { float_property: 12.5 }).validate

        expect(errors[:float_property].full_messages).to contain_exactly(
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

      it "should return the right hash of error messages when value of property is not of type integer" do
        errors =
          described_class.new(schema: schema, object: { integer_property: "string" }).validate

        expect(errors[:integer_property].full_messages).to contain_exactly("must be an integer")

        errors = described_class.new(schema: schema, object: { integer_property: 1.0 }).validate

        expect(errors[:integer_property].full_messages).to contain_exactly("must be an integer")
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

        expect(errors[:integer_property].full_messages).to contain_exactly(
          "must be larger than or equal to 5",
        )

        errors = described_class.new(schema: schema, object: { integer_property: 11 }).validate

        expect(errors[:integer_property].full_messages).to contain_exactly(
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

      it "should return the right hash of error messages when value of property is not of type string" do
        schema = { name: "section", properties: { string_property: { type: "string" } } }
        errors = described_class.new(schema: schema, object: { string_property: 1 }).validate

        expect(errors[:string_property].full_messages).to contain_exactly("must be a string")
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

        expect(errors[:string_property].full_messages).to contain_exactly("must be a valid URL")
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

        expect(errors[:string_property].full_messages).to contain_exactly(
          "must be at least 5 characters long",
        )

        errors =
          described_class.new(schema: schema, object: { string_property: "12345678910" }).validate

        expect(errors[:string_property].full_messages).to contain_exactly(
          "must be at most 10 characters long",
        )
      end
    end

    context "for category properties" do
      it "should not return any error message when the value of the property is a valid id of a category record" do
        category = Fabricate(:category)

        schema = { name: "section", properties: { category_property: { type: "category" } } }

        expect(
          described_class.new(schema: schema, object: { category_property: category.id }).validate,
        ).to eq({})
      end

      it "should return the right hash of error messages when value of property is not an integer" do
        schema = { name: "section", properties: { category_property: { type: "category" } } }

        errors =
          described_class.new(schema: schema, object: { category_property: "string" }).validate

        expect(errors[:category_property].full_messages).to contain_exactly(
          "must be a valid category id",
        )
      end

      it "should return the right hash of error messages when value of property is not a valid id of a category record" do
        category = Fabricate(:category)

        schema = {
          name: "section",
          properties: {
            category_property: {
              type: "category",
            },
            category_property_2: {
              type: "category",
            },
            child_categories: {
              type: "objects",
              schema: {
                name: "child_category",
                properties: {
                  category_property_3: {
                    type: "category",
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
                schema: schema,
                object: {
                  category_property: 99_999_999,
                  category_property_2: 99_999_999,
                  child_categories: [
                    { category_property_3: 99_999_999 },
                    { category_property_3: category.id },
                  ],
                },
              ).validate

            expect(errors[:category_property].full_messages).to contain_exactly(
              "must be a valid category id",
            )

            expect(errors[:category_property_2].full_messages).to contain_exactly(
              "must be a valid category id",
            )

            expect(
              errors[:child_categories][0][:category_property_3].full_messages,
            ).to contain_exactly("must be a valid category id")

            expect(errors[:child_categories][1]).to eq({})
          end

        # only 1 SQL query should be executed to check if category ids are valid
        expect(queries.length).to eq(1)
      end
    end
  end
end
