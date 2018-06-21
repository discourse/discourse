class ActiveRecord::Base

  # Execute SQL manually
  def self.exec_sql(*args)

    Discourse.deprecate("exec_sql should not be used anymore, please use DB.exec or DB.query instead!")

    conn = ActiveRecord::Base.connection
    sql = ActiveRecord::Base.send(:sanitize_sql_array, args)
    conn.raw_connection.async_exec(sql)
  end

  def exec_sql(*args)
    ActiveRecord::Base.exec_sql(*args)
  end

  # Executes the given block +retries+ times (or forever, if explicitly given nil),
  # catching and retrying SQL Deadlock errors.
  #
  # Thanks to: http://stackoverflow.com/a/7427186/165668
  #
  def self.retry_lock_error(retries = 5, &block)
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

end
