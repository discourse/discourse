# frozen_string_literal: true

Migrations::Database::Schema.configure do
  output do
    schema_file "db/intermediate_db_schema/100-base-schema.sql"

    models_directory "lib/database/intermediate_db"
    models_namespace "Migrations::Database::IntermediateDB"

    enums_directory "lib/database/intermediate_db/enums"
    enums_namespace "Migrations::Database::IntermediateDB::Enums"
  end
end
