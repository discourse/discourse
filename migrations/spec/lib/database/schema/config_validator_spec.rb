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

  context "with schema config" do
    context "with incorrect global config" do
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
end
