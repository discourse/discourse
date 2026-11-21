# frozen_string_literal: true

require "tmpdir"

# A migrated IntermediateDB with a migrated mappings DB attached as `mapped`,
# the way the importer steps see them. Exposes the connection as `db`.
RSpec.shared_context "with mapped intermediate db" do
  around do |example|
    Dir.mktmpdir do |dir|
      intermediate_path = File.join(dir, "intermediate.db")
      mappings_path = File.join(dir, "mappings.db")

      Migrations::Database.migrate(
        intermediate_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      Migrations::Database.migrate(
        mappings_path,
        migrations_path: Migrations::Database::MAPPINGS_DB_SCHEMA_PATH,
      )

      @db = Migrations::Database.connect(intermediate_path)
      @db.execute("ATTACH DATABASE ? AS mapped", mappings_path)
      example.run
    ensure
      @db&.close
    end
  end

  let(:db) { @db }
end
