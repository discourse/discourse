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
    allow(ActiveRecord::Base.connection).to receive(:columns).with("categories").and_return(
      [
        instance_double(
          ActiveRecord::ConnectionAdapters::PostgreSQL::Column,
          name: "id",
          type: :integer,
        ),
        instance_double(
          ActiveRecord::ConnectionAdapters::PostgreSQL::Column,
          name: "name",
          type: :string,
        ),
      ],
    )
    allow(ActiveRecord::Base.connection).to receive(:columns).with("topics").and_return(
      [
        instance_double(
          ActiveRecord::ConnectionAdapters::PostgreSQL::Column,
          name: "id",
          type: :integer,
        ),
        instance_double(
          ActiveRecord::ConnectionAdapters::PostgreSQL::Column,
          name: "title",
          type: :string,
        ),
      ],
    )
    allow(Discourse).to receive(:plugins).and_return([])
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

    it "detects that `include` and `exclude` of columns can't be used togehter" do
      config = minimal_config
      config[:schema][:tables][:users][:columns] = { include: ["id"], exclude: ["username"] }

      expect(validator.validate(config)).to have_errors
      expect(validator.errors).to contain_exactly(
        I18n.t(
          "schema.validator.include_exclude_not_allowed",
          path: "`/schema/tables/users/columns`",
        ),
      )
    end
  end

  # context "with output config" do
  #   it "checks if directory of `schema_file` exists" do
  #     config = minimal_config
  #     config[:output][:schema_file] = "foo/bar/100-base-schema.sql"
  #     expect(validator.validate(config)).to have_errors
  #     expect(validator.errors).to contain_exactly(
  #       I18n.t("schema.validator.output.schema_file_directory_not_found"),
  #     )
  #   end
  #
  #   it "checks if `models_directory` exists" do
  #     config = minimal_config
  #     config[:output][:models_directory] = "foo/bar"
  #     expect(validator.validate(config)).to have_errors
  #     expect(validator.errors).to contain_exactly(
  #       I18n.t("schema.validator.output.models_directory_not_found"),
  #     )
  #   end
  #
  #   it "checks if `models_namespace` is an existing namespace" do
  #     config = minimal_config
  #     config[:output][:models_namespace] = "Foo::Bar::IntermediateDB"
  #     expect(validator.validate(config)).to have_errors
  #     expect(validator.errors).to contain_exactly(
  #       I18n.t("schema.validator.output.models_namespace_undefined"),
  #     )
  #   end
  # end

  context "with schema config" do
    context "with incorrect global config" do
      it "detects globally excluded tables that do not exist" do
        config = minimal_config
        config[:schema][:global][:tables][:exclude] = %w[users foo bar]
        config[:schema][:tables] = {}

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t("schema.validator.global.excluded_tables_missing", table_names: "bar, foo"),
        )
      end

      it "detects globally excluded tables that are used in `schema/tables` section" do
        allow(ActiveRecord::Base.connection).to receive(:tables).and_return(%w[categories users])

        config = minimal_config
        config[:schema][:global][:tables][:exclude] = %w[categories users]
        config[:schema][:tables] = {
          categories: {
            columns: {
              include: %w[id name],
            },
          },
          users: {
            columns: {
              include: %w[id username],
            },
          },
        }

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t("schema.validator.global.excluded_tables_used", table_names: "categories, users"),
        )
      end

      it "detects globally excluded columns that do not match existing columns" do
        config = minimal_config
        config[:schema][:global][:columns][:exclude] = %w[foo username bar]

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t("schema.validator.global.excluded_columns_missing", column_names: "bar, foo"),
        )
      end

      xit "detects globally modified columns that do not match existing columns" do
        config = minimal_config
        config[:schema][:global][:columns][:exclude] = [
          { name: "foo", datatype: "text" },
          { name: "id", datatype: "text" },
          { name_regex: "bar.*", datatype: "text" },
          { name_regex: "user.*", datatype: "integer" },
        ]

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t("schema.validator.global.modified_tables_missing", table_names: "/bar.*/, foo"),
        )
      end
    end

    context "with incorrect table config" do
      it "detects tables that are missing from configuration file" do
        allow(ActiveRecord::Base.connection).to receive(:tables).and_return(
          %w[categories topics posts users tags],
        )

        config = minimal_config
        config[:schema][:global][:tables][:exclude] = %w[categories]
        config[:schema][:tables] = {
          topics: {
            columns: {
              include: %w[id title],
            },
          },
          users: {
            columns: {
              include: %w[id username],
            },
          },
        }

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t("schema.validator.table_not_configured", table_name: "posts"),
          I18n.t("schema.validator.table_not_configured", table_name: "tags"),
        )
      end
    end

    context "with incorrect column config" do
      it "detects that a newly added column already exists" do
        config = minimal_config
        config[:schema][:tables][:users][:columns] = {
          add: [
            { name: "name", datatype: "text" },
            { name: "username", datatype: "text" },
            { name: "id", datatype: "text" },
          ],
        }

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to include(
          I18n.t(
            "schema.validator.tables.added_columns_exist",
            table_name: "users",
            column_names: "id, username",
          ),
        )
      end

      it "detects that an included column does not exist" do
        config = minimal_config
        config[:schema][:tables][:users][:columns][:include] = %w[foo id bar username]

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t(
            "schema.validator.tables.included_columns_missing",
            table_name: "users",
            column_names: "bar, foo",
          ),
        )
      end

      it "detects that an excluded column does not exist" do
        config = minimal_config
        config[:schema][:tables][:users][:columns] = { exclude: %w[foo username bar] }

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t(
            "schema.validator.tables.excluded_columns_missing",
            table_name: "users",
            column_names: "bar, foo",
          ),
        )
      end

      it "detects that a modified column does not exist" do
        config = minimal_config
        config[:schema][:tables][:users][:columns] = {
          include: ["id"],
          modify: [
            { name: "username", datatype: "integer" },
            { name: "foo", datatype: "integer" },
            { name: "bar", datatype: "text" },
          ],
        }

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t(
            "schema.validator.tables.modified_columns_missing",
            table_name: "users",
            column_names: "bar, foo",
          ),
        )
      end

      it "detects that a modified column is included" do
        config = minimal_config
        config[:schema][:tables][:users][:columns] = {
          include: %w[id username],
          modify: [{ name: "username", datatype: "integer" }],
        }

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t(
            "schema.validator.tables.modified_columns_included",
            table_name: "users",
            column_names: "username",
          ),
        )
      end

      it "detects that a modified column is excluded" do
        config = minimal_config
        config[:schema][:tables][:users][:columns] = {
          exclude: %w[username],
          modify: [{ name: "username", datatype: "integer" }],
        }

        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t(
            "schema.validator.tables.modified_columns_excluded",
            table_name: "users",
            column_names: "username",
          ),
        )
      end

      it "detects that not all existing columns are either included, excluded or modified" do
        config = minimal_config

        config[:schema][:tables][:users][:columns] = { exclude: %w[username] }
        expect(validator.validate(config)).to_not have_errors

        config[:schema][:tables][:users][:columns] = { include: [] }
        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t(
            "schema.validator.tables.not_all_columns_configured",
            table_name: "users",
            column_names: "id, username",
          ),
        )

        config[:schema][:tables][:users][:columns] = { include: ["id"] }
        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t(
            "schema.validator.tables.not_all_columns_configured",
            table_name: "users",
            column_names: "username",
          ),
        )

        config[:schema][:tables][:users][:columns] = {
          include: [],
          modify: [{ name: "username", datatype: "integer" }],
        }
        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t(
            "schema.validator.tables.not_all_columns_configured",
            table_name: "users",
            column_names: "id",
          ),
        )

        config[:schema][:tables][:users][:columns] = {
          include: ["id"],
          modify: [{ name: "username", datatype: "integer" }],
        }
        expect(validator.validate(config)).to_not have_errors
      end

      it "detects that a table has no columns" do
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
            instance_double(
              ActiveRecord::ConnectionAdapters::PostgreSQL::Column,
              name: "views",
              type: :integer,
            ),
            instance_double(
              ActiveRecord::ConnectionAdapters::PostgreSQL::Column,
              name: "created_at",
              type: :datetime,
            ),
          ],
        )

        config = minimal_config
        config[:schema][:global][:columns][:exclude] = ["created_at"]

        config[:schema][:tables][:users][:columns] = { exclude: ["views"] }
        expect(validator.validate(config)).to_not have_errors

        config[:schema][:tables][:users][:columns] = { exclude: %w[id username views] }
        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t("schema.validator.tables.no_columns_configured", table_name: "users"),
        )

        config[:schema][:tables][:users][:columns] = {
          exclude: %w[id username views],
          add: [{ name: "foo", datatype: "integer" }],
        }
        expect(validator.validate(config)).to_not have_errors

        config[:schema][:tables][:users][:columns] = { include: %w[id username views] }
        expect(validator.validate(config)).to_not have_errors

        config[:schema][:tables][:users][:columns] = { include: ["created_at"] }
        expect(validator.validate(config)).to have_errors
        expect(validator.errors).to contain_exactly(
          I18n.t(
            "schema.validator.tables.not_all_columns_configured",
            table_name: "users",
            column_names: "id, username, views",
          ),
        )
      end
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
      expect(validator.errors).to contain_exactly(
        I18n.t("schema.validator.plugins.not_installed", plugin_names: "bar, foo"),
      )
    end

    it "detects if an active plugin isn't configured" do
      config = minimal_config
      config[:plugins] = %w[poll]

      expect(validator.validate(config)).to have_errors
      expect(validator.errors).to contain_exactly(
        I18n.t("schema.validator.plugins.additional_installed", plugin_names: "chat, footnote"),
      )
    end
  end
end
