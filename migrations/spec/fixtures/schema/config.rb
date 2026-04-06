# frozen_string_literal: true

Migrations::Database::Schema.configure do
  output do
    schema_file "db/test_schema/100-base-schema.sql"
    models_directory "lib/database/test_db"
    models_namespace "Migrations::Database::TestDB"
    enums_directory "lib/database/test_db/enums"
    enums_namespace "Migrations::Database::TestDB::Enums"
  end
end
