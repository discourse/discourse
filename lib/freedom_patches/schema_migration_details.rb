module FreedomPatches
  module SchemaMigrationDetails
    def exec_migration(conn, direction)
      rval = nil

      time = Benchmark.measure { rval = super }

      sql = <<SQL
      INSERT INTO schema_migration_details(
        version,
        hostname,
        name,
        git_version,
        duration,
        direction,
        rails_version,
        created_at
      ) values (
        :version,
        :hostname,
        :name,
        :git_version,
        :duration,
        :direction,
        :rails_version,
        :created_at
      )
SQL

      hostname =
        begin
          `hostname`
        rescue StandardError
          ''
        end
      sql =
        ActiveRecord::Base.send(
          :sanitize_sql_array,
          [
            sql,
            {
              version: version || '',
              duration: (time.real * 1000).to_i,
              hostname: hostname,
              name: name,
              git_version: Discourse.git_version,
              created_at: Time.zone.now,
              direction: direction.to_s,
              rails_version: Rails.version
            }
          ]
        )

      conn.execute(sql)

      rval
    end
  end
end

class ActiveRecord::Migration
  prepend FreedomPatches::SchemaMigrationDetails
end
