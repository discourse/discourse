class ActiveRecord::Base  

  # Execute SQL manually
  def self.exec_sql(*args)
    conn = ActiveRecord::Base.connection
    sql = ActiveRecord::Base.send(:sanitize_sql_array, args)
    conn.execute(sql)
  end

  def self.exec_sql_row_count(*args)
    exec_sql(*args).cmd_tuples  
  end

  def exec_sql(*args)
    ActiveRecord::Base.exec_sql(*args)
  end

  # Support for psql. If we want to support multiple RDBMs in the future we can
  # split this.
  def exec_sql_row_count(*args)
    exec_sql(*args).cmd_tuples
  end

end