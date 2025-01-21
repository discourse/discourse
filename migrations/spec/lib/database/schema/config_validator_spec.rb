# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Schema::ConfigValidator do
  subject(:validator) { described_class.new }

  def minimal_config
    {
      output: {
        schema_file: "db/intermediate_db_schema/100-base-schema.sql",
        models_directory: "lib/database/intermediate_db",
        models_namespace: "Migrations::Database::IntermediateDB",
      },
      schema: {
        tables: {
          users: {
            columns: {
              include: %w[id username],
            },
          },
        },
        global: {
          columns: {
          },
          tables: {
          },
        },
      },
      plugins: [],
    }
  end

  before do
    allow(ActiveRecord::Base.connection).to receive(:tables).and_return(["users"])
    allow(ActiveRecord::Base.connection).to receive(:columns).with("users").and_return(
      [
        instance_double(
          ActiveRecord::ConnectionAdapters::PostgreSQL::Column,
          name: "id",
          type: :integer,
        ),
        instance_double(
          ActiveRecord::ConnectionAdapters::PostgreSQL::Column,
          name: "username",
          type: :string,
        ),
      ],
    )
  end

  it "validates the minimal config" do
    expect(validator.validate(minimal_config)).to_not have_errors
    expect(validator.errors).to be_empty
  end

  context "with JSON schema" do
    it "detects missing required properties" do
      expect(validator.validate({})).to have_errors
      expect(validator.errors).to contain_exactly(
        "object at root is missing required properties: output, schema, plugins",
      )
    end

    it "detects nested, missing required properties" do
      incomplete_config = minimal_config.except(:plugins)
      incomplete_config[:schema].except!(:global)

      expect(validator.validate(incomplete_config)).to have_errors
      expect(validator.errors).to contain_exactly(
        "object at `/schema` is missing required properties: global",
        "object at root is missing required properties: plugins",
      )
    end

    it "detects datatype mismatches" do
      invalid_config = minimal_config
      invalid_config[:output][:models_namespace] = 123

      expect(validator.validate(invalid_config)).to have_errors
      expect(validator.errors).to contain_exactly(
        "value at `/output/models_namespace` is not a string",
      )
    end
  end

  context "with output config" do
    it "checks if directory of `schema_file` exists" do
      config = minimal_config
      config[:output][:schema_file] = "foo/bar/100-base-schema.sql"
      expect(validator.validate(config)).to have_errors
      expect(validator.errors).to contain_exactly("Directory of `schema_file` does not exist")
    end

    it "checks if `models_directory` exists" do
      config = minimal_config
      config[:output][:models_directory] = "foo/bar"
      expect(validator.validate(config)).to have_errors
      expect(validator.errors).to contain_exactly("`models_directory` does not exist")
    end

    it "checks if `models_namespace` is an existing namespace" do
      config = minimal_config
      config[:output][:models_namespace] = "Foo::Bar::IntermediateDB"
      expect(validator.validate(config)).to have_errors
      expect(validator.errors).to contain_exactly("`models_namespace` is not defined")
    end
  end

  context "with schema config" do
    it "detects excluded tables that do not exist" do
      config = minimal_config
      config[:schema][:global][:tables][:exclude] = %w[users foo bar]
      config[:schema][:tables] = {}

      expect(validator.validate(config)).to have_errors
      expect(validator.errors).to contain_exactly(
        "Excluded table does not exist: bar",
        "Excluded table does not exist: foo",
      )
    end

    it "detects excluded tables that are used in `schema/tables` section" do
      allow(ActiveRecord::Base.connection).to receive(:tables).and_return(%w[categories users])

      config = minimal_config
      config[:schema][:global][:tables][:exclude] = %w[categories users]
      config[:schema][:tables] = { categories: {}, users: {} }

      expect(validator.validate(config)).to have_errors
      expect(validator.errors).to contain_exactly(
        "Excluded table can't be configured in `schema/tables` section: categories",
        "Excluded table can't be configured in `schema/tables` section: users",
      )
    end
  end

  context "with plugins config" do
    before do
      allow(Discourse).to receive(:plugins).and_return(
        [
          instance_double(::Plugin::Instance, name: "footnote"),
          instance_double(::Plugin::Instance, name: "chat"),
          instance_double(::Plugin::Instance, name: "poll"),
        ],
      )
    end

    it "detects if a configured plugin is missing" do
      config = minimal_config
      config[:plugins] = %w[foo poll bar chat footnote]

      expect(validator.validate(config)).to have_errors
      expect(validator.errors).to contain_exactly("Configured plugins not installed: bar, foo")
    end

    it "detects if an active plugin isn't configured" do
      config = minimal_config
      config[:plugins] = %w[poll]

      expect(validator.validate(config)).to have_errors
      expect(validator.errors).to contain_exactly(
        "Additional plugins installed. Uninstall them or add to configuration: chat, footnote",
      )
    end
  end
end
