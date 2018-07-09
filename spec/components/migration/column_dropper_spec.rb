require 'rails_helper'
require_dependency 'migration/column_dropper'

RSpec.describe Migration::ColumnDropper do

  def has_column?(table, column)
    DB.exec(<<~SQL, table: table, column: column) == 1
      SELECT 1
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE
        table_schema = 'public' AND
        table_name = :table AND
        column_name = :column
    SQL
  end

  def update_first_migration_date(created_at)
    DB.exec(<<~SQL, created_at: created_at)
        UPDATE schema_migration_details
        SET created_at = :created_at
        WHERE id = (SELECT MIN(id)
                    FROM schema_migration_details)
    SQL
  end

  describe ".drop" do
    let(:migration_name) do
      DB.query_single("SELECT name FROM schema_migration_details ORDER BY id DESC LIMIT 1").first
    end

    before do
      DB.exec "ALTER TABLE topics ADD COLUMN junk int"

      DB.exec(<<~SQL, name: migration_name, created_at: 15.minutes.ago)
        UPDATE schema_migration_details
        SET created_at = :created_at
        WHERE name = :name
      SQL
    end

    it "can correctly drop columns after correct delay" do
      dropped_proc_called = false
      after_dropped_proc_called = false
      update_first_migration_date(2.years.ago)

      Migration::ColumnDropper.drop(
        table: 'topics',
        after_migration: migration_name,
        columns: ['junk'],
        delay: 20.minutes,
        on_drop: ->() { dropped_proc_called = true },
        after_drop: ->() { after_dropped_proc_called = true }
      )

      expect(has_column?('topics', 'junk')).to eq(true)
      expect(dropped_proc_called).to eq(false)
      expect(dropped_proc_called).to eq(false)

      Migration::ColumnDropper.drop(
        table: 'topics',
        after_migration: migration_name,
        columns: ['junk'],
        delay: 10.minutes,
        on_drop: ->() { dropped_proc_called = true },
        after_drop: ->() { after_dropped_proc_called = true }
      )

      expect(has_column?('topics', 'junk')).to eq(false)
      expect(dropped_proc_called).to eq(true)
      expect(after_dropped_proc_called).to eq(true)

      dropped_proc_called = false
      after_dropped_proc_called = false

      Migration::ColumnDropper.drop(
        table: 'topics',
        after_migration: migration_name,
        columns: ['junk'],
        delay: 10.minutes,
        on_drop: ->() { dropped_proc_called = true },
        after_drop: ->() { after_dropped_proc_called = true }
      )

      # it should call "on_drop" only when there are columns to drop
      expect(dropped_proc_called).to eq(false)
      expect(after_dropped_proc_called).to eq(false)
    end

    it "drops the columns immediately if the first migration was less than 10 minutes ago" do
      dropped_proc_called = false
      update_first_migration_date(11.minutes.ago)

      Migration::ColumnDropper.drop(
        table: 'topics',
        after_migration: migration_name,
        columns: ['junk'],
        delay: 30.minutes,
        on_drop: ->() { dropped_proc_called = true }
      )

      expect(has_column?('topics', 'junk')).to eq(true)
      expect(dropped_proc_called).to eq(false)

      update_first_migration_date(9.minutes.ago)

      Migration::ColumnDropper.drop(
        table: 'topics',
        after_migration: migration_name,
        columns: ['junk'],
        delay: 30.minutes,
        on_drop: ->() { dropped_proc_called = true }
      )

      expect(has_column?('topics', 'junk')).to eq(false)
      expect(dropped_proc_called).to eq(true)
    end
  end

  describe '.mark_readonly' do
    let(:table_name) { "table_with_readonly_column" }

    before do
      DB.exec <<~SQL
      CREATE TABLE #{table_name} (topic_id INTEGER, email TEXT);

      INSERT INTO #{table_name} (topic_id, email)
      VALUES (1, 'something@email.com');
      SQL

      Migration::ColumnDropper.mark_readonly(table_name, 'email')
    end

    after do
      ActiveRecord::Base.connection.reset!

      DB.exec <<~SQL
      DROP TABLE IF EXISTS #{table_name};
      DROP TRIGGER IF EXISTS #{table_name}_email_readonly ON #{table_name};
      SQL
    end

    it 'should be droppable' do
      name = DB.query_single("SELECT name FROM schema_migration_details LIMIT 1").first

      dropped_proc_called = false
      Migration::ColumnDropper.drop(
        table: table_name,
        after_migration: name,
        columns: ['email'],
        delay: 0.minutes,
        on_drop: ->() { dropped_proc_called = true }
      )

      expect(dropped_proc_called).to eq(true)

    end
    it 'should prevent updates to the readonly column' do
      expect do
        DB.exec <<~SQL
        UPDATE #{table_name}
        SET email = 'testing@email.com'
        WHERE topic_id = 1;
        SQL
      end.to raise_error(
        PG::RaiseException,
        /Discourse: email in #{table_name} is readonly/
      )
    end

    it 'should allow updates to the other columns' do
      DB.exec <<~SQL
      UPDATE #{table_name}
      SET topic_id = 2
      WHERE topic_id = 1
      SQL

      expect(
        ActiveRecord::Base.exec_sql("SELECT * FROM #{table_name};").values
      ).to include([2, "something@email.com"])
    end

    it 'should prevent insertions to the readonly column' do
      expect do
        ActiveRecord::Base.connection.raw_connection.exec <<~SQL
        INSERT INTO #{table_name} (topic_id, email)
        VALUES (2, 'something@email.com');
        SQL
      end.to raise_error(
        PG::RaiseException,
        /Discourse: email in table_with_readonly_column is readonly/
      )
    end

    it 'should allow insertions to the other columns' do
      DB.exec <<~SQL
      INSERT INTO #{table_name} (topic_id)
      VALUES (2);
      SQL

      expect(
        DB.query_single("SELECT topic_id FROM #{table_name} WHERE topic_id = 2")
      ).to eq([2])
    end
  end
end
