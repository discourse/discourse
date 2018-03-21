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

    ActiveRecord::Base.exec_sql(sql).to_a.length > 0
  end

  let(:migration_name) do
    ActiveRecord::Base
      .exec_sql("SELECT name FROM schema_migration_details LIMIT 1")
      .getvalue(0, 0)
  end

  before do
    ActiveRecord::Base.exec_sql "CREATE TABLE table_with_old_name (topic_id INTEGER)"

    Topic.exec_sql("UPDATE schema_migration_details SET created_at = :created_at WHERE name = :name",
                   name: migration_name, created_at: 15.minutes.ago)
  end

  describe "#delayed_rename" do
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

      ActiveRecord::Base.exec_sql "CREATE TABLE table_with_new_name (topic_id INTEGER)"

      described_class.delayed_rename(
        old_name: 'table_with_old_name',
        new_name: 'table_with_new_name',
        after_migration: migration_name,
        delay: 10.minutes,
        on_drop: ->() { dropped_proc_called = true }
      )

      expect(table_exists?('table_with_old_name')).to eq(false)
      expect(dropped_proc_called).to eq(true)
    end
  end

  describe "#delayed_drop" do
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
    end
  end
end
