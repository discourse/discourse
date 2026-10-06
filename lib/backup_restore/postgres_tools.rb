# frozen_string_literal: true

require "open3"

module BackupRestore
  module PostgresTools
    # The installation layouts also searched by TemporaryDb, including client-only installs.
    BIN_DIRECTORIES = %w[
      /usr/lib/postgresql/*/bin
      /usr/pgsql-*/bin
      /Applications/Postgres.app/Contents/Versions/*/bin
      /opt/local/lib/postgresql*/bin
      /opt/homebrew/opt/postgresql@*/bin
      /usr/local/opt/postgresql@*/bin
      /opt/postgresql*/bin
    ].freeze

    def self.find(command, server_version:)
      dumping = command == "pg_dump"
      candidates =
        binary_paths(command).filter_map do |path|
          output, _stderr, status = Open3.capture3(path, "--version")
          version = output[/\(PostgreSQL\) (\d+)\./, 1]&.to_i
          next unless status.success? && version
          next unless dumping ? version >= server_version : version <= server_version
          [path, version]
        end

      selected = dumping ? candidates.min_by(&:last) : candidates.max_by(&:last)
      return selected.first if selected

      raise "No compatible #{command} found for PostgreSQL #{server_version}. " \
              "Install PostgreSQL client tools version #{server_version} or #{dumping ? "newer" : "older"}."
    end

    def self.binary_paths(command)
      directories = Dir.glob(BIN_DIRECTORIES) + ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
      directories
        .map { |directory| File.join(directory, command) }
        .uniq
        .select { |path| File.file?(path) && File.executable?(path) }
    end
  end
end
