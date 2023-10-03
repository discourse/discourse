# frozen_string_literal: true
require "pg"
require "date"

usage = <<-TEXT
Commands:
  ruby db_timestamp_updater.rb yesterday <date> move all timestamps by x days so that <date> will be moved to yesterday
  ruby db_timestamp_updater.rb 100              move all timestamps forward by 100 days
  ruby db_timestamp_updater.rb -100             move all timestamps backward by 100 days
TEXT

class TimestampsUpdater
  def initialize(schema, ignore_tables)
    @schema = schema
    @ignore_tables = ignore_tables
    @raw_connection =
      PG.connect(
        host: ENV["DISCOURSE_DB_HOST"] || "localhost",
        port: ENV["DISCOURSE_DB_PORT"] || 5432,
        dbname: ENV["DISCOURSE_DB_NAME"] || "discourse_development",
        user: ENV["DISCOURSE_DB_USERNAME"] || "postgres",
        password: ENV["DISCOURSE_DB_PASSWORD"] || "",
      )
  end

  def move_by(days)
    postgresql_date_types = ["timestamp without time zone", "timestamp with time zone", "date"]

    postgresql_date_types.each do |data_type|
      columns = all_columns_of_type(data_type)
      columns.each do |c|
        table = c["table_name"]
        next if @ignore_tables.include? table
        column = c["column_name"]

        if has_unique_index(table, column)
          move_timestamps_respect_constraints(table, column, days)
        else
          move_timestamps(table, column, days)
        end
      end
    end
  end

  def move_to_yesterday(date)
    days = (Date.today.prev_day - date).to_i
    move_by days
  end

  private

  def all_columns_of_type(data_type)
    sql = <<~SQL
      SELECT c.column_name, c.table_name
      FROM information_schema.columns AS c
      JOIN information_schema.tables AS t
        ON c.table_name = t.table_name
      WHERE c.table_schema = '#{@schema}'
        AND t.table_schema = '#{@schema}'
        AND c.data_type = '#{data_type}'
        AND t.table_type = 'BASE TABLE'
    SQL
    @raw_connection.exec(sql)
  end

  def has_unique_index(table, column)
    # This detects unique indices created with "CREATE UNIQUE INDEX".
    # This also detects unique constraints and primary keys,
    # because postgresql creates unique indices for them.
    sql = <<~SQL
      SELECT 1
      FROM pg_class t,
           pg_class i,
           pg_index ix,
           pg_attribute a,
           pg_namespace ns
      WHERE t.oid = ix.indrelid
        AND i.oid = ix.indexrelid
        AND a.attrelid = t.oid
        AND a.attnum = ANY (ix.indkey)
        AND t.relnamespace = ns.oid
        AND ns.nspname = '#{@schema}'
        AND t.relname = '#{table}'
        AND a.attname = '#{column}'
        AND ix.indisunique
      LIMIT 1;
    SQL
    result = @raw_connection.exec(sql)
    result.any?
  end

  def move_timestamps(table_name, column_name, days)
    operator = days < 0 ? "-" : "+"
    interval_expression = "#{operator} INTERVAL '#{days.abs} days'"
    update_table(table_name, column_name, interval_expression)
  end

  def move_timestamps_respect_constraints(table_name, column_name, days)
    # add 1000 years to the interval to avoid uniqueness conflicts:
    operator = days < 0 ? "-" : "+"
    interval_expression = "#{operator} INTERVAL '1000 years #{days.abs} days'"
    update_table(table_name, column_name, interval_expression)

    # return back by 1000 years:
    operator = days < 0 ? "+" : "-"
    interval_expression = "#{operator} INTERVAL '1000 years'"
    update_table(table_name, column_name, interval_expression)
  end

  def update_table(table_name, column_name, interval_expression)
    sql = <<~SQL
      UPDATE #{table_name}
      SET #{column_name} = #{column_name} #{interval_expression}
    SQL
    @raw_connection.exec(sql)
  end
end

def is_i?(string)
  begin
    true if Integer(string)
  rescue StandardError
    false
  end
end

def is_date?(string)
  begin
    true if Date.parse(string)
  rescue StandardError
    false
  end
end

def create_updater
  ignore_tables = %w[user_second_factors]
  TimestampsUpdater.new "public", ignore_tables
end

if ARGV.length == 2 && ARGV[0] == "yesterday" && is_date?(ARGV[1])
  date = Date.parse(ARGV[1])
  updater = create_updater
  updater.move_to_yesterday date
elsif ARGV.length == 1 && is_i?(ARGV[0])
  days = ARGV[0].to_i
  updater = create_updater
  updater.move_by days
else
  puts usage
  exit 1
end
