# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::PropertySchemaValidator do
  def validate(schema)
    described_class.call("test:node", schema).map(&:to_s)
  end

  describe ".call" do
    it "accepts a valid schema" do
      schema = {
        method: {
          type: :options,
          required: true,
          default: "GET",
          options: %w[GET POST],
          no_data_expression: true,
        },
        url: {
          type: :string,
          required: true,
          display_options: {
            show: {
              method: %w[POST],
            },
          },
          ui: {
            dynamic_value: :url,
          },
        },
      }
      expect(validate(schema)).to eq([])
    end

    it "flags unknown field types" do
      errors = validate(age: { type: :age })
      expect(errors.first).to include("age.type")
      expect(errors.first).to include("unknown type: :age")
    end

    it "rejects camelCase field type aliases" do
      expect(validate(rows: { type: :fixedCollection }).first).to include(
        "unknown type: :fixedCollection",
      )
      expect(validate(rows: { type: :assignmentCollection }).first).to include(
        "unknown type: :assignmentCollection",
      )
    end

    it "flags unknown top-level field keys" do
      errors = validate(title: { type: :string, expression: true })
      expect(errors.first).to include("[:expression]")
    end

    it "rejects camelCase field option aliases" do
      errors =
        validate(
          title: {
            type: :string,
            displayOptions: {
              show: {
              },
            },
            typeOptions: {
              maxAllowedFields: 1,
            },
          },
        )
      expect(errors.first).to include(":displayOptions")
      expect(errors.first).to include(":typeOptions")
    end

    it "flags unknown ui keys" do
      errors = validate(title: { type: :string, ui: { rowz: 6 } })
      expect(errors.first).to include("title.ui")
      expect(errors.first).to include(":rowz")
    end

    it "accepts filter query ui metadata" do
      schema = { query: { type: :string, ui: { control: :filter_query, filter: :posts } } }

      expect(validate(schema)).to eq([])
    end

    it "accepts checkbox controls" do
      schema = { enabled: { type: :boolean, ui: { control: :checkbox } } }

      expect(validate(schema)).to eq([])
    end

    it "accepts user seen trigger option controls" do
      schema = {
        trigger_conditions: {
          type: :custom,
          ui: {
            control: :user_seen_trigger_options,
          },
        },
      }

      expect(validate(schema)).to eq([])
    end

    it "flags unknown ui.control values" do
      errors = validate(title: { type: :string, ui: { control: :neon } })
      expect(errors.first).to include("title.ui.control")
      expect(errors.first).to include(":neon")
    end

    it "accepts control_options with known keys" do
      schema = {
        picker: {
          type: :integer,
          ui: {
            control: :combo_box,
          },
          control_options: {
            action_icon: "plus",
            action_label: "discourse_workflows.actions.manage",
            action_route: "adminPlugins.show.example",
            action_route_models: ["example-plugin"],
            filterable: true,
            value_property: "id",
            name_property: "name",
          },
        },
      }
      expect(validate(schema)).to eq([])
    end

    it "flags unknown control_options keys" do
      errors = validate(picker: { type: :integer, control_options: { rowz: 3 } })
      expect(errors.first).to include("picker.control_options")
      expect(errors.first).to include(":rowz")
    end

    it "rejects camelCase type_options keys" do
      errors =
        validate(
          rows: {
            type: :fixed_collection,
            options: [{ name: "values", values: { cell: { type: :string } } }],
            type_options: {
              maxAllowedFields: 3,
            },
          },
        )
      expect(errors.first).to include("rows.type_options")
      expect(errors.first).to include(":maxAllowedFields")
    end

    it "requires :options for option-typed fields" do
      errors = validate(choice: { type: :options, default: "a" })
      expect(errors.first).to include("type :options requires")
    end

    it "allows dynamic option fields to declare a load options method" do
      schema = {
        choice: {
          type: :options,
          default: "a",
          type_options: {
            load_options_method: "choices",
          },
        },
      }

      expect(validate(schema)).to eq([])
    end

    it "allows credential_type on credential fields" do
      schema = { credential_id: { type: :credential, credential_type: :basic_auth } }
      expect(validate(schema)).to eq([])
    end

    it "rejects credential_type on non-credential fields" do
      errors = validate(title: { type: :string, credential_type: :basic_auth })
      expect(errors.first).to include(":credential_type")
    end

    it "lets fixed collection fields reference siblings in the same group" do
      schema = {
        rows: {
          type: :fixed_collection,
          options: [
            {
              name: "values",
              values: {
                kind: {
                  type: :options,
                  options: %w[text dropdown],
                },
                choices: {
                  type: :fixed_collection,
                  display_options: {
                    show: {
                      kind: %w[dropdown],
                    },
                  },
                  options: [{ name: "values", values: { label: { type: :string } } }],
                },
              },
            },
          ],
        },
      }
      expect(validate(schema)).to eq([])
    end

    it "requires :options for multi_options fields" do
      errors = validate(choices: { type: :multi_options })
      expect(errors.first).to include(":multi_options")
    end

    it "requires :options for collection fields" do
      errors = validate(rows: { type: :collection })
      expect(errors.first).to include("type :collection requires")
    end

    it "requires :options for fixed collection fields" do
      errors = validate(rows: { type: :fixed_collection })
      expect(errors.first).to include("type :fixed_collection requires")
    end

    it "recurses into fixed collection group values" do
      errors =
        validate(
          rows: {
            type: :fixed_collection,
            options: [{ name: "values", values: { cell: { type: :unknown } } }],
          },
        )
      expect(errors.first).to include("rows.options.0.values.cell.type")
    end

    it "recurses into collection option bag fields" do
      errors = validate(rows: { type: :collection, options: [{ name: "enabled", type: :unknown }] })
      expect(errors.first).to include("rows.options.enabled.type")
    end

    it "rejects camelCase display names in collection definitions" do
      option_errors =
        validate(
          rows: {
            type: :collection,
            options: [{ name: "enabled", type: :boolean, displayName: "Enabled" }],
          },
        )

      expect(option_errors.first).to include("rows.options.enabled")
      expect(option_errors.first).to include(":displayName")

      group_errors =
        validate(
          rows: {
            type: :fixed_collection,
            options: [
              { name: "values", displayName: "Values", values: { cell: { type: :string } } },
            ],
          },
        )

      expect(group_errors.first).to include("rows.options.0")
      expect(group_errors.first).to include(":displayName")
    end

    it "flags display_options references to nonexistent sibling fields" do
      errors = validate(body: { type: :string, display_options: { show: { methud: %w[POST] } } })
      expect(errors.first).to include("display_options")
      expect(errors.first).to include(":methud")
    end

    it "accepts display_options show rules within the same scope" do
      schema = {
        method: {
          type: :options,
          options: %w[GET POST],
        },
        body: {
          type: :string,
          display_options: {
            show: {
              method: %w[POST],
            },
          },
        },
      }
      expect(validate(schema)).to eq([])
    end

    it "accepts display_options hide rules" do
      schema = {
        method: {
          type: :options,
          options: %w[GET POST],
        },
        warning: {
          type: :notice,
          display_options: {
            hide: {
              method: %w[POST],
            },
          },
        },
      }
      expect(validate(schema)).to eq([])
    end

    it "requires visibility rules to be a hash" do
      errors = validate(body: { type: :string, display_options: { show: "yes" } })
      expect(errors.first).to include("display_options.show")
      expect(errors.first).to include("Hash")
    end

    it "requires display_options rule values to be arrays" do
      errors =
        validate(
          method: {
            type: :options,
            options: %w[GET POST],
          },
          body: {
            type: :string,
            display_options: {
              show: {
                method: "POST",
              },
            },
          },
        )

      expect(errors.first).to include("display_options.show.method")
      expect(errors.first).to include("Array")
    end

    it "scopes sibling checks to the current schema level" do
      schema = {
        rules: {
          type: :fixed_collection,
          options: [
            {
              name: "values",
              values: {
                kind: {
                  type: :options,
                  options: %w[a b],
                },
                detail: {
                  type: :string,
                  display_options: {
                    show: {
                      kind: %w[a],
                    },
                  },
                },
              },
            },
          ],
        },
      }
      expect(validate(schema)).to eq([])
    end
  end

  describe ".validate_all" do
    it "passes for every registered node" do
      errors = described_class.validate_all
      expect(errors).to eq([]), -> { errors.map(&:to_s).join("\n") }
    end
  end
end
