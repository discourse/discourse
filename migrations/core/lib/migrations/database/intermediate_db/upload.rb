# frozen_string_literal: true

module Migrations
  module Database
    module IntermediateDB
      module Upload
        SQL = <<~SQL
          INSERT OR IGNORE INTO uploads (
              id,
              filename,
              path,
              data,
              url,
              type,
              description,
              origin,
              user_id
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        SQL
        private_constant :SQL

        # `uploads` rows are content-identical for a given `id` (a hash of the
        # file's path/url/data), and several steps legitimately reference the same
        # file, so a duplicate `id` is expected rather than an error. Both the
        # insert (`SQL` above) and the shard merge take first-writer-wins via
        # `INSERT OR IGNORE` — see `IntermediateDB.conflict_strategy_for`.
        def self.conflict_strategy
          :ignore
        end

        def self.create_for_file(
          path:,
          filename: nil,
          type: nil,
          description: nil,
          origin: nil,
          user_id: nil
        )
          create(
            id: Migrations::ID.hash(path),
            filename: filename || File.basename(path),
            path:,
            type:,
            description:,
            origin:,
            user_id:,
          )
        end

        def self.create_for_url(
          url:,
          filename:,
          type: nil,
          description: nil,
          origin: nil,
          user_id: nil
        )
          create(
            id: Migrations::ID.hash(url),
            filename:,
            url:,
            type:,
            description:,
            origin:,
            user_id:,
          )
        end

        def self.create_for_data(
          data:,
          filename:,
          type: nil,
          description: nil,
          origin: nil,
          user_id: nil
        )
          create(
            id: Migrations::ID.hash(data),
            filename:,
            data: Migrations::Database.to_blob(data),
            type:,
            description:,
            origin:,
            user_id:,
          )
        end

        def self.create(
          id:,
          filename:,
          path: nil,
          data: nil,
          url: nil,
          type: nil,
          description: nil,
          origin: nil,
          user_id: nil
        )
          Migrations::Database::IntermediateDB.insert(
            SQL,
            id,
            filename,
            path,
            data,
            url,
            type,
            description,
            origin,
            user_id,
          )

          id
        end
      end
    end
  end
end
