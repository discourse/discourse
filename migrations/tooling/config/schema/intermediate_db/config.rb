# frozen_string_literal: true

Migrations::Tooling::Schema.configure do
  output do
    schema_file "db/intermediate_db_schema/100-base-schema.sql"

    models_directory "lib/migrations/database/intermediate_db"
    models_namespace "Migrations::Database::IntermediateDB"

    enums_directory "lib/migrations/database/intermediate_db/enums"
    enums_namespace "Migrations::Database::IntermediateDB::Enums"
  end
end
