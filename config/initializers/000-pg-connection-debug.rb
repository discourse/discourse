# frozen_string_literal: true

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def self.new_client(conn_params)
    start = Time.now()
    PG.connect(**conn_params)
  rescue ::PG::Error => error
    if conn_params && conn_params[:dbname] == "postgres"
      raise ActiveRecord::ConnectionNotEstablished, error.message
    elsif conn_params && conn_params[:dbname] && error.message.include?(conn_params[:dbname])
      Rails.logger.error(
        "DebuggingNoDatabaseError: #{error.message} after #{Time.now() - start}s\n#{error.backtrace.join("\n")}",
      )
      raise ActiveRecord::NoDatabaseError.db_error(conn_params[:dbname])
    elsif conn_params && conn_params[:user] && error.message.include?(conn_params[:user])
      raise ActiveRecord::DatabaseConnectionError.username_error(conn_params[:user])
    elsif conn_params && conn_params[:host] && error.message.include?(conn_params[:host])
      raise ActiveRecord::DatabaseConnectionError.hostname_error(conn_params[:host])
    else
      raise ActiveRecord::ConnectionNotEstablished, error.message
    end
  end
end
