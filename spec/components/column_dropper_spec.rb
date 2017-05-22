require 'rails_helper'
require 'column_dropper'

describe ColumnDropper do

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
            .getvalue(0,0)

    Topic.exec_sql("UPDATE schema_migration_details SET created_at = :created_at WHERE name = :name",
                  name: name, created_at: 15.minutes.ago)

    dropped_proc_called = false

    ColumnDropper.drop(
      table: 'topics',
      after_migration: name,
      columns: ['junk'],
      delay: 20.minutes,
      on_drop: ->(){dropped_proc_called = true}
    )

    expect(has_column?('topics', 'junk')).to eq(true)
    expect(dropped_proc_called).to eq(false)

    ColumnDropper.drop(
      table: 'topics',
      after_migration: name,
      columns: ['junk'],
      delay: 10.minutes,
      on_drop: ->(){dropped_proc_called = true}
    )

    expect(has_column?('topics', 'junk')).to eq(false)
    expect(dropped_proc_called).to eq(true)

  end
end

