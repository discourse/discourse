class Remap
  def initialize(from, to, regex: false, verbose: false)
    @from = from
    @to = to
    @regex = regex
    @verbose = verbose
  end

  def perform
    sql = "SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema='public' and (data_type like 'char%' or data_type like 'text%') and is_updatable = 'YES'"

    cnn = ActiveRecord::Base.connection.raw_connection

    results = cnn.async_exec(sql).to_a

    results.each do |result|
      table_name = result["table_name"]
      column_name = result["column_name"]

      log "Remapping #{table_name} #{column_name}"

      result = if @regex
        cnn.async_exec("UPDATE #{table_name}
          SET #{column_name} = regexp_replace(#{column_name}, $1, $2, 'g')
          WHERE NOT #{column_name} IS NULL
            AND #{column_name} <> regexp_replace(#{column_name}, $1, $2, 'g')", [@from, @to])
      else
        cnn.async_exec("UPDATE #{table_name}
          SET #{column_name} = replace(#{column_name}, $1, $2)
          WHERE NOT #{column_name} IS NULL
            AND #{column_name} <> replace(#{column_name}, $1, $2)", [@from, @to])
      end

      log "#{result.cmd_tuples} rows affected!"
    end
  end

  def log(message)
    puts(message) if @verbose
  end
end
