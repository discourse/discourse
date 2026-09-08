# frozen_string_literal: true

Migrations::Tooling::Schema.configure do
  output do
    schema_file "db/files_db_schema/100-base-schema.sql"

    models_directory "lib/migrations/database/files_db"
    models_namespace "Migrations::Database::FilesDB"

    enums_directory "lib/migrations/database/files_db/enums"
    enums_namespace "Migrations::Database::FilesDB::Enums"
  end
end
