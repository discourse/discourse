# frozen_string_literal: true
require "pg"

usage = <<-END
Commands:
  ruby db_timestamp_updater.rb yesterday <date> move all timestamps by x days so that <date> will be moved to yesterday
  ruby db_timestamp_updater.rb 100              move all timestamps forward by 100 days
  ruby db_timestamp_updater.rb -100             move all timestamps backward by 100 days
END

class TimestampsUpdater
  def initialize(schema, ignore_tables)
    @schema = schema
    @ignore_tables = ignore_tables
    @raw_connection = PG.connect(
      host: ENV['DISCOURSE_DB_HOST'] || 'localhost',
      port: ENV['DISCOURSE_DB_PORT'] || 5432,
      dbname: ENV['DISCOURSE_DB_NAME'] || 'discourse_development',
      user: ENV['DISCOURSE_DB_USERNAME'] || 'postgres',
      password: ENV['DISCOURSE_DB_PASSWORD'] || '')
  end

  def move_by(days)
    postgresql_date_types = [
      "timestamp without time zone",
      "timestamp with time zone",
      "date"
    ]

    postgresql_date_types.each do |data_type|
      columns = all_columns_of_type(data_type)
      columns.each do |c|
        table = c["table_name"]
        next if @ignore_tables.include? table
        column = c["column_name"]

        move_timestamps table, column, days
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

  def move_timestamps(table_name, column_name, days)
    operator = days < 0 ? "-" : "+"
    sql = <<~SQL
      UPDATE #{table_name}
      SET #{column_name} = #{column_name} #{operator} INTERVAL '#{days.abs} day'
    SQL
    @raw_connection.exec(sql)
  end
end

def is_i?(string)
  true if Integer(string) rescue false
end

def is_date?(string)
  true if Date.parse(string) rescue false
end

def create_updater
  ignore_tables = %w[application_requests user_visits]
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
