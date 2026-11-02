# frozen_string_literal: true

require "pg"

module Migrations
  module Database
    module Drivers
      # PostgreSQL connections stay open while workers are forked.
      class Postgres
        # @param settings [Hash] the connection parameters for `PG::Connection.new`
        # @param field_names [Symbol] `:string` or `:symbol`, the key type of result hashes
        # @param quiet [Boolean] whether to suppress notices from the server
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
          # PQfinish writes Terminate. Redirect the socket first so it cannot close
          # the parent's session.
          connection.socket_io.reopen(IO::NULL)
        end
      end
    end
  end
end
