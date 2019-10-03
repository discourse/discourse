# frozen_string_literal: true

require 'rails_helper'

describe Migration::SafeMigrate do
  before do
    Migration::SafeMigrate::SafeMigration.disable_safe!
  end

  after do
    Migration::SafeMigrate.disable!
    Migration::SafeMigrate::SafeMigration.enable_safe!
  end

  def migrate_up(path)
    migrations = ActiveRecord::MigrationContext.new(path, ActiveRecord::SchemaMigration).migrations
    ActiveRecord::Migrator.new(:up, migrations, ActiveRecord::SchemaMigration, migrations.first.version).run
  end

  it "bans all table removal" do
    Migration::SafeMigrate.enable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/drop_table"

    output = capture_stdout do
      expect(lambda do
        migrate_up(path)
      end).to raise_error(StandardError)
    end

    expect(output).to include("rails g post_migration")

    expect { User.first }.not_to raise_error
    expect(User.first).not_to eq(nil)
  end

  it "bans all table renames" do
    Migration::SafeMigrate.enable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/rename_table"

    output = capture_stdout do
      expect(lambda do
        migrate_up(path)
      end).to raise_error(StandardError)
    end

    expect { User.first }.not_to raise_error
    expect(User.first).not_to eq(nil)

    expect(output).to include("rails g post_migration")
  end

  it "bans all column removal" do
    Migration::SafeMigrate.enable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/remove_column"

    output = capture_stdout do
      expect(lambda do
        migrate_up(path)
      end).to raise_error(StandardError)
    end

    expect(output).to include("rails g post_migration")

    expect(User.first).not_to eq(nil)
    expect { User.first.username }.not_to raise_error
  end

  it "bans all column renames" do
    Migration::SafeMigrate.enable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/rename_column"

    output = capture_stdout do
      expect(lambda do
        migrate_up(path)
      end).to raise_error(StandardError)
    end

    expect(output).to include("rails g post_migration")

    expect(User.first).not_to eq(nil)
    expect { User.first.username }.not_to raise_error
  end

  it "supports being disabled" do
    Migration::SafeMigrate.enable!
    Migration::SafeMigrate.disable!

    path = File.expand_path "#{Rails.root}/spec/fixtures/db/migrate/drop_table"

    output = capture_stdout do
      migrate_up(path)
    end

    expect(output).to include("drop_table(:email_logs)")
  end

  describe 'for a post deployment migration' do
    it 'should not ban unsafe migrations' do
      user = Fabricate(:user)
      Migration::SafeMigrate::SafeMigration.enable_safe!

      path = File.expand_path "#{Rails.root}/spec/fixtures/db/post_migrate"

      output = capture_stdout do
        migrate_up(path)
      end

      expect(output).to include("drop_table(:email_logs)")
      expect(user.reload).to eq(user)
    end
  end
end
