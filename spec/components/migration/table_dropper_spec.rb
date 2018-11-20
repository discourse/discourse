require 'rails_helper'
require_dependency 'migration/table_dropper'

describe Migration::TableDropper do

  def table_exists?(table_name)
    sql = <<~SQL
      SELECT 1
      FROM INFORMATION_SCHEMA.TABLES
      WHERE table_schema = 'public' AND
            table_name = '#{table_name}'
    SQL

    DB.exec(sql) > 0
  end

  def update_first_migration_date(created_at)
    DB.exec(<<~SQL, created_at: created_at)
        UPDATE schema_migration_details
        SET created_at = :created_at
        WHERE id = (SELECT MIN(id)
                    FROM schema_migration_details)
    SQL
  end

  def create_new_table
    DB.exec "CREATE TABLE table_with_new_name (topic_id INTEGER)"
  end

  let(:migration_name) do
    DB.query_single("SELECT name FROM schema_migration_details ORDER BY id DESC LIMIT 1").first
  end

  before do
    DB.exec "CREATE TABLE table_with_old_name (topic_id INTEGER)"

    DB.exec(<<~SQL, name: migration_name, created_at: 15.minutes.ago)
      UPDATE schema_migration_details
      SET created_at = :created_at
      WHERE name = :name
    SQL
  end

  context "first migration was a long time ago" do
    before do
      update_first_migration_date(2.years.ago)
    end

    describe ".delayed_rename" do
      it "can drop a table after correct delay and when new table exists" do
        dropped_proc_called = false

        described_class.delayed_rename(
          old_name: 'table_with_old_name',
          new_name: 'table_with_new_name',
          after_migration: migration_name,
          delay: 20.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        expect(table_exists?('table_with_old_name')).to eq(true)
        expect(dropped_proc_called).to eq(false)

        described_class.delayed_rename(
          old_name: 'table_with_old_name',
          new_name: 'table_with_new_name',
          after_migration: migration_name,
          delay: 10.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        expect(table_exists?('table_with_old_name')).to eq(true)
        expect(dropped_proc_called).to eq(false)

        create_new_table

        described_class.delayed_rename(
          old_name: 'table_with_old_name',
          new_name: 'table_with_new_name',
          after_migration: migration_name,
          delay: 10.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        expect(table_exists?('table_with_old_name')).to eq(false)
        expect(dropped_proc_called).to eq(true)

        dropped_proc_called = false

        described_class.delayed_rename(
          old_name: 'table_with_old_name',
          new_name: 'table_with_new_name',
          after_migration: migration_name,
          delay: 10.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        # it should call "on_drop" only when there is a table to drop
        expect(dropped_proc_called).to eq(false)
      end
    end

    describe ".delayed_drop" do
      it "can drop a table after correct delay" do
        dropped_proc_called = false

        described_class.delayed_drop(
          table_name: 'table_with_old_name',
          after_migration: migration_name,
          delay: 20.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        expect(table_exists?('table_with_old_name')).to eq(true)
        expect(dropped_proc_called).to eq(false)

        described_class.delayed_drop(
          table_name: 'table_with_old_name',
          after_migration: migration_name,
          delay: 10.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        expect(table_exists?('table_with_old_name')).to eq(false)
        expect(dropped_proc_called).to eq(true)

        dropped_proc_called = false

        described_class.delayed_drop(
          table_name: 'table_with_old_name',
          after_migration: migration_name,
          delay: 10.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        # it should call "on_drop" only when there is a table to drop
        expect(dropped_proc_called).to eq(false)
      end
    end
  end

  context "first migration was a less than 10 minutes ago" do
    describe ".delayed_rename" do
      it "can drop a table after correct delay and when new table exists" do
        dropped_proc_called = false
        update_first_migration_date(11.minutes.ago)
        create_new_table

        described_class.delayed_rename(
          old_name: 'table_with_old_name',
          new_name: 'table_with_new_name',
          after_migration: migration_name,
          delay: 30.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        expect(table_exists?('table_with_old_name')).to eq(true)
        expect(dropped_proc_called).to eq(false)

        update_first_migration_date(9.minutes.ago)

        described_class.delayed_rename(
          old_name: 'table_with_old_name',
          new_name: 'table_with_new_name',
          after_migration: migration_name,
          delay: 30.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        expect(table_exists?('table_with_old_name')).to eq(false)
        expect(dropped_proc_called).to eq(true)
      end
    end

    describe ".delayed_drop" do
      it "immediately drops the table" do
        dropped_proc_called = false
        update_first_migration_date(11.minutes.ago)

        described_class.delayed_drop(
          table_name: 'table_with_old_name',
          after_migration: migration_name,
          delay: 30.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        expect(table_exists?('table_with_old_name')).to eq(true)
        expect(dropped_proc_called).to eq(false)

        update_first_migration_date(9.minutes.ago)

        described_class.delayed_drop(
          table_name: 'table_with_old_name',
          after_migration: migration_name,
          delay: 30.minutes,
          on_drop: ->() { dropped_proc_called = true }
        )

        expect(table_exists?('table_with_old_name')).to eq(false)
        expect(dropped_proc_called).to eq(true)
      end
    end
  end
end
