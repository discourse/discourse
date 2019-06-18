# frozen_string_literal: true

class ActiveRecord::Base

  # Handle PG::UniqueViolation as well due to concurrency
  # find_or_create does find_by(hash) || create!(hash)
  # in some cases find will not find and multiple creates will be called
  #
  # note: Rails 6 has: https://github.com/rails/rails/blob/c83e30da27eafde79164ecb376e8a28ccc8d841f/activerecord/lib/active_record/relation.rb#L171-L201
  # This means that in Rails 6 we would either use:
  #
  # create_or_find_by! (if we are generally creating)
  #
  # OR
  #
  # find_by(hash) || create_or_find_by(hash)  (if we are generally finding)
  def self.find_or_create_by_safe!(hash)
    begin
      find_or_create_by!(hash)
    rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # try again cause another transaction could have passed by now
      find_or_create_by!(hash)
    end
  end

  # Execute SQL manually
  def self.exec_sql(*args)

    Discourse.deprecate("exec_sql should not be used anymore, please use DB.exec or DB.query instead!")

    conn = ActiveRecord::Base.connection
    sql = ActiveRecord::Base.public_send(:sanitize_sql_array, args)
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
