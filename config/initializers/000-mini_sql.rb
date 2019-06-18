# frozen_string_literal: true

require 'mini_sql_multisite_connection'
::DB = MiniSqlMultisiteConnection.instance
