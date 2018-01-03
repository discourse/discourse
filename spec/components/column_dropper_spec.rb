require 'rails_helper'
require 'column_dropper'

RSpec.describe ColumnDropper do

  def has_column?(table, column)
    Topic.exec_sql("SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE
                      table_schema = 'public' AND
                      table_name = :table AND
                      column_name = :column
                   ",
                      table: table, column: column
                  ).to_a.length == 1
  end

  it "can correctly drop columns after correct delay" do
    Topic.exec_sql "ALTER TABLE topics ADD COLUMN junk int"
    name = Topic
      .exec_sql("SELECT name FROM schema_migration_details LIMIT 1")
      .getvalue(0, 0)

    Topic.exec_sql("UPDATE schema_migration_details SET created_at = :created_at WHERE name = :name",
                  name: name, created_at: 15.minutes.ago)

    dropped_proc_called = false

    ColumnDropper.drop(
      table: 'topics',
      after_migration: name,
      columns: ['junk'],
      delay: 20.minutes,
      on_drop: ->() { dropped_proc_called = true }
    )

    expect(has_column?('topics', 'junk')).to eq(true)
    expect(dropped_proc_called).to eq(false)

    ColumnDropper.drop(
      table: 'topics',
      after_migration: name,
      columns: ['junk'],
      delay: 10.minutes,
      on_drop: ->() { dropped_proc_called = true }
    )

    expect(has_column?('topics', 'junk')).to eq(false)
    expect(dropped_proc_called).to eq(true)

  end

  describe '.mark_readonly' do
    let(:table_name) { "table_with_readonly_column" }

    before do
      ActiveRecord::Base.exec_sql <<~SQL
      CREATE TABLE #{table_name} (topic_id INTEGER, email TEXT);

      INSERT INTO #{table_name} (topic_id, email)
      VALUES (1, 'something@email.com');
      SQL

      ColumnDropper.mark_readonly(table_name, 'email')
    end

    after do
      ActiveRecord::Base.connection.reset!

      ActiveRecord::Base.exec_sql <<~SQL
      DROP TABLE IF EXISTS #{table_name};
      DROP TRIGGER IF EXISTS #{table_name}_email_readonly ON #{table_name};
      SQL
    end

    it 'should be droppable' do
      name = Topic
        .exec_sql("SELECT name FROM schema_migration_details LIMIT 1")
        .getvalue(0, 0)

      dropped_proc_called = false
      ColumnDropper.drop(
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
        ActiveRecord::Base.connection.raw_connection.exec <<~SQL
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
      ActiveRecord::Base.exec_sql <<~SQL
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
      ActiveRecord::Base.exec_sql <<~SQL
      INSERT INTO #{table_name} (topic_id)
      VALUES (2);
      SQL

      expect(
        ActiveRecord::Base.exec_sql("SELECT * FROM #{table_name} WHERE topic_id = 2;").values
      ).to include([2, nil])
    end
  end
end
