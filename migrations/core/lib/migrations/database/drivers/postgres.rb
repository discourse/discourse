# frozen_string_literal: true

require "pg"

module Migrations
  module Database
    module Drivers
      class Postgres
        def initialize(settings, field_names: :string, quiet: false)
          @settings = settings
          @field_names = field_names
          @quiet = quiet
        end

        def fork_policy
          :discard
        end

        def open
          PG::Connection.new(@settings)
        end

        def configure(connection)
          connection.type_map_for_results = PG::BasicTypeMapForResults.new(connection)
          connection.field_name_type = @field_names
          connection.exec("SET client_min_messages TO WARNING") if @quiet
        end

        def close(connection)
          connection.finish unless connection.finished?
        end

        def discard(connection)
          return if connection.finished?
          # PQfinish writes Terminate. Redirect the descriptor before any native
          # cleanup can reach the parent's session; redirection failures are fatal.
          connection.socket_io.reopen(IO::NULL)
        end
      end
    end
  end
end
