# frozen_string_literal: true

RSpec.describe Migration::SafeMigrate do
  before { Migration::SafeMigrate::SafeMigration.disable_safe! }

  after do
    Migration::SafeMigrate.disable!
    Migration::SafeMigrate::SafeMigration.enable_safe!
  end

  def migrate_up(path)
    migrations = ActiveRecord::MigrationContext.new(path).migrations
    ActiveRecord::Migrator.new(
      :up,
      migrations,
      ActiveRecord::Base.connection_pool.schema_migration,
      ActiveRecord::Base.connection_pool.internal_metadata,
      migrations.first.version,
    ).run
  end

  it "bans all table removal" do
    Migration::SafeMigrate.enable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/drop_table"

    output = capture_stdout { expect do migrate_up(path) end.to raise_error(StandardError) }

    expect(output).to include("rails g post_migration")

    expect { User.first }.not_to raise_error
    expect(User.first).not_to eq(nil)
  end

  it "bans all table renames" do
    Migration::SafeMigrate.enable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/rename_table"

    output = capture_stdout { expect do migrate_up(path) end.to raise_error(StandardError) }

    expect { User.first }.not_to raise_error
    expect(User.first).not_to eq(nil)

    expect(output).to include("rails g post_migration")
  end

  it "bans all column removal" do
    Migration::SafeMigrate.enable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/remove_column"

    output = capture_stdout { expect do migrate_up(path) end.to raise_error(StandardError) }

    expect(output).to include("rails g post_migration")

    expect(User.first).not_to eq(nil)
    expect { User.first.username }.not_to raise_error
  end

  it "bans all column renames" do
    Migration::SafeMigrate.enable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/rename_column"

    output = capture_stdout { expect do migrate_up(path) end.to raise_error(StandardError) }

    expect(output).to include("rails g post_migration")

    expect(User.first).not_to eq(nil)
    expect { User.first.username }.not_to raise_error
  end

  it "allows running a migration that creates an index concurrently if it checks if the index exists first" do
    Migration::SafeMigrate.enable!

    path =
      File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/create_index_concurrently_safe_activerecord"

    error = nil

    capture_stdout do
      begin
        migrate_up(path)
      rescue StandardError => e
        error = e
      end
    end

    expect(error.cause.cause.message).to include(
      "CREATE INDEX CONCURRENTLY cannot run inside a transaction block",
    )
  end

  it "allows running a migration that creates an index concurrently if it drops the index first" do
    Migration::SafeMigrate.enable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/create_index_concurrently_safe"
    error = nil

    capture_stdout do
      begin
        migrate_up(path)
      rescue StandardError => e
        error = e
      end
    end

    expect(error.cause.cause.message).to include(
      "CREATE INDEX CONCURRENTLY cannot run inside a transaction block",
    )
  end

  it "bans running a migration that creates an index concurrently without first dropping the index if it exists" do
    Migration::SafeMigrate.enable!

    path =
      File.expand_path("#{Rails.root}/spec/fixtures/db/migrate/create_index_concurrently_unsafe")

    error = nil

    capture_stdout do
      migrate_up(path)
    rescue StandardError => e
      error = e
    end

    expect(error.message).to include(
      "An attempt was made to create an index concurrently in a migration without first dropping the index.",
    )
  end

  it "allows dropping NOT NULL" do
    Migration::SafeMigrate.enable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/drop_not_null"

    output = capture_stdout { migrate_up(path) }

    expect(output).to include("change_column_null(:users, :username, true, nil)")
  end

  it "supports being disabled" do
    Migration::SafeMigrate.enable!
    Migration::SafeMigrate.disable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/drop_table"

    output = capture_stdout { migrate_up(path) }

    expect(output).to include("drop_table(:email_logs)")
  end

  describe "for a post deployment migration" do
    it "should not ban unsafe migrations using up" do
      Migration::SafeMigrate::SafeMigration.enable_safe!

      path = File.expand_path "#{Rails.root}/spec/fixtures/db/post_migrate/drop_table"

      output = capture_stdout { migrate_up(path) }

      expect(output).to include("drop_table(:email_logs)")
    end

    it "should not ban unsafe migrations using change" do
      Migration::SafeMigrate::SafeMigration.enable_safe!

      path = File.expand_path "#{Rails.root}/spec/fixtures/db/post_migrate/change"

      output = capture_stdout { migrate_up(path) }

      expect(output).to include("drop_table(:email_logs)")
    end
  end
end
