# frozen_string_literal: true

module Voice
  class DefaultRoomSeeder
    DEFAULT_NAME = "Watercooler"
    MUTEX = "voice-default-room-seeder"

    class << self
      def ensure!
        return unless SiteSetting.voice_enabled?
        return unless schema_ready?
        return if Voice::Room.persistent.exists?

        # Runs at plugin activation, which can precede pending migrations (dev
        # DBs, rake db:migrate itself) — and Room queries the newest columns.
        # DatabaseTasks.migrations_paths is the set that includes plugin paths;
        # the connection pool's migration_context only knows core's.
        if ActiveRecord::MigrationContext.new(
             ActiveRecord::Tasks::DatabaseTasks.migrations_paths,
           ).needs_migration?
          return
        end

        DistributedMutex.synchronize(MUTEX) do
          next if Voice::Room.persistent.exists?

          room =
            Voice::Room.create!(
              name: DEFAULT_NAME,
              description: I18n.t("voice.defaults.watercooler_description"),
              public: true,
              creator: Discourse.system_user,
            )

          Voice::DirectoryBroadcaster.broadcast(action: :created, room: room)
        end
      end

      private

      def schema_ready?
        @schema_ready ||= {}
        site = RailsMultisite::ConnectionManagement.current_db
        return true if @schema_ready[site]

        connection = ActiveRecord::Base.connection
        @schema_ready[site] = connection.table_exists?(:voice_rooms) &&
          connection.column_exists?(:voice_rooms, :ephemeral)
      end
    end
  end
end
