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

  def self.sql_fragment(*sql_array)
    ActiveRecord::Base.send(:sanitize_sql_array, sql_array)
  end

  # exists fine in rails4
  unless rails4?
    # note: update_attributes still spins up a transaction this can cause contention
    # this method performs the raw update sidestepping the locking
    # exists in rails 4
    def update_columns(hash)
      self.class.where(self.class.primary_key => self.id).update_all(hash)

      hash.each do |k,v|
        raw_write_attribute k, v
      end
    end
  end

  def exec_sql(*args)
    ActiveRecord::Base.exec_sql(*args)
  end


  # Executes the given block +retries+ times (or forever, if explicitly given nil),
  # catching and retrying SQL Deadlock errors.
  #
  # Thanks to: http://stackoverflow.com/a/7427186/165668
  #
  def self.retry_lock_error(retries=5, &block)
    begin
      yield
    rescue ActiveRecord::StatementInvalid => e
      if e.message =~ /deadlock detected/ && (retries.nil? || retries > 0)
        retry_lock_error(retries ? retries - 1 : nil, &block)
      else
        raise e
      end
    end
  end

  # Support for psql. If we want to support multiple RDBMs in the future we can
  # split this.
  def exec_sql_row_count(*args)
    exec_sql(*args).cmd_tuples
  end

end
