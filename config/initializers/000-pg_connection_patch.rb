# frozen_string_literal: true

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def self.new_client(conn_params)
    start = Time.now()
    PG.connect(**conn_params)
  rescue ::PG::Error => error
    if conn_params && conn_params[:dbname] == "postgres"
      raise ActiveRecord::ConnectionNotEstablished, error.message
      # === PATCH START ===
      # PostgreSQL's error message for a missing database looks something like this `FATAL:  database "<databasename>" does not exist`.
      # This patch updates the following conditional to be stricter and not match on other error messages that may contain the database name.
      # For example, `<database>-some-host" (<some IP>), port 5432 failed: timeout expired after 11.30376464s` should not be considered
      # a missing database error.
      #
      # Ideally, we want to include more of the missing database error message but we are unsure if the error message
      # will change based on a user's locale and whether the locale is even selectable. The workaround now is already much better
      # than the existing conditional.
    elsif conn_params && conn_params[:dbname] &&
          error.message.include?("\"#{conn_params[:dbname]}\"")
      raise ActiveRecord::NoDatabaseError.db_error(conn_params[:dbname])
      # === PATCH END ===
    elsif conn_params && conn_params[:user] && error.message.include?(conn_params[:user])
      # === PATCH START ===
      error_message =
        ActiveRecord::DatabaseConnectionError.username_error(conn_params[:user]).message
      raise ActiveRecord::DatabaseConnectionError.new("#{error_message}\n#{error.message}")
      # === PATCH END ===
    elsif conn_params && conn_params[:host] && error.message.include?(conn_params[:host])
      # === PATCH START ===
      error_message =
        ActiveRecord::DatabaseConnectionError.hostname_error(conn_params[:host]).message
      raise ActiveRecord::DatabaseConnectionError.new("#{error_message}\n#{error.message}")
      # === PATCH END ===
    else
      raise ActiveRecord::ConnectionNotEstablished, error.message
    end
  end
end
