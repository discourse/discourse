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
          ui: {
            expression: false,
          },
        },
        url: {
          type: :string,
          required: true,
          visible_if: {
            method: %w[POST],
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

    it "flags unknown top-level field keys" do
      errors = validate(title: { type: :string, expression: true })
      expect(errors.first).to include("[:expression]")
    end

    it "flags unknown ui keys" do
      errors = validate(title: { type: :string, ui: { rowz: 6 } })
      expect(errors.first).to include("title.ui")
      expect(errors.first).to include(":rowz")
    end

    it "flags unknown ui.control values" do
      errors = validate(title: { type: :string, ui: { control: :neon } })
      expect(errors.first).to include("title.ui.control")
      expect(errors.first).to include(":neon")
    end

    it "requires :options for option-typed fields" do
      errors = validate(choice: { type: :options, default: "a" })
      expect(errors.first).to include("type :options requires")
    end

    it "allows credential_type on credential fields" do
      schema = { credential_id: { type: :credential, credential_type: :basic_auth } }
      expect(validate(schema)).to eq([])
    end

    it "rejects credential_type on non-credential fields" do
      errors = validate(title: { type: :string, credential_type: :basic_auth })
      expect(errors.first).to include(":credential_type")
    end

    it "lets extra_item_schema reference item_schema siblings" do
      schema = {
        rows: {
          type: :collection,
          item_schema: {
            kind: {
              type: :options,
              options: %w[text dropdown],
            },
          },
          extra_item_schema: {
            choices: {
              type: :collection,
              visible_if: {
                kind: %w[dropdown],
              },
              item_schema: {
                label: {
                  type: :string,
                },
              },
            },
          },
        },
      }
      expect(validate(schema)).to eq([])
    end

    it "requires :options for multi_options fields" do
      errors = validate(choices: { type: :multi_options })
      expect(errors.first).to include(":multi_options")
    end

    it "requires :item_schema for collection fields" do
      errors = validate(rows: { type: :collection })
      expect(errors.first).to include(":collection requires :item_schema")
    end

    it "recurses into item_schema" do
      errors = validate(rows: { type: :collection, item_schema: { cell: { type: :unknown } } })
      expect(errors.first).to include("rows.item_schema.cell.type")
    end

    it "flags visible_if references to nonexistent sibling fields" do
      errors = validate(body: { type: :string, visible_if: { methud: %w[POST] } })
      expect(errors.first).to include("visible_if")
      expect(errors.first).to include(":methud")
    end

    it "accepts visible_if references within the same scope" do
      schema = {
        method: {
          type: :options,
          options: %w[GET POST],
        },
        body: {
          type: :string,
          visible_if: {
            method: %w[POST],
          },
        },
      }
      expect(validate(schema)).to eq([])
    end

    it "accepts visible_unless rules" do
      schema = {
        method: {
          type: :options,
          options: %w[GET POST],
        },
        warning: {
          type: :notice,
          visible_unless: {
            method: %w[POST],
          },
        },
      }
      expect(validate(schema)).to eq([])
    end

    it "requires visibility rules to be a hash" do
      errors = validate(body: { type: :string, visible_if: "yes" })
      expect(errors.first).to include("visible_if")
      expect(errors.first).to include("Hash")
    end

    it "scopes sibling checks to the current schema level" do
      schema = {
        rules: {
          type: :collection,
          item_schema: {
            kind: {
              type: :options,
              options: %w[a b],
            },
            detail: {
              type: :string,
              visible_if: {
                kind: %w[a],
              },
            },
          },
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
