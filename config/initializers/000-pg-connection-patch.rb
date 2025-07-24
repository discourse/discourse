# frozen_string_literal: true

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  # This patch removes the default behavior of the adapter where it raises the `ActiveRecord::NoDatabaseError`,
  # `ActiveRecord::DatabaseConnectionError`, or `ActiveRecord::ConnectionNotEstablished` errors as long as the error
  # message contains the database name, user, or host. This is not ideal since the error message may contain the database
  # name, user or host even if the connection is not established due to other reasons. In addition, when those error
  # messages are raised, the underlying PG error message is lost, which makes debugging difficult. We prefer to just
  # debug based on the original PG error message and do not need generic error messages from Rails.
  def new_client(conn_params)
    PG.connect(**conn_params)
  rescue ::PG::Error => error
    # PATCH START
    # if conn_params && conn_params[:dbname] == "postgres"
    #   raise ActiveRecord::ConnectionNotEstablished, error.message
    # elsif conn_params && conn_params[:dbname] && error.message.include?(conn_params[:dbname])
    #   raise ActiveRecord::NoDatabaseError.db_error(conn_params[:dbname])
    # elsif conn_params && conn_params[:user] && error.message.include?(conn_params[:user])
    #   raise ActiveRecord::DatabaseConnectionError.username_error(conn_params[:user])
    # elsif conn_params && conn_params[:host] && error.message.include?(conn_params[:host])
    #   raise ActiveRecord::DatabaseConnectionError.hostname_error(conn_params[:host])
    # else
    raise ActiveRecord::ConnectionNotEstablished, error.message
    # end
    # PATCH END
  end
end
