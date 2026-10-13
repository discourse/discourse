# frozen_string_literal: true

module Live
  class DefaultRoomSeeder
    DEFAULT_NAME = "Watercooler"
    MUTEX = "live-default-room-seeder"

    def self.ensure!
      return unless SiteSetting.live_enabled?
      return unless schema_ready?
      return if Live::Room.persistent.exists?

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
        next if Live::Room.persistent.exists?

        room =
          Live::Room.create!(
            name: DEFAULT_NAME,
            description: I18n.t("live.defaults.watercooler_description"),
            public: true,
            creator: Discourse.system_user,
          )

        Live::DirectoryBroadcaster.broadcast(action: :created, room: room)
      end
    end

    def self.schema_ready?
      @schema_ready ||= {}
      site = RailsMultisite::ConnectionManagement.current_db
      return true if @schema_ready[site]

      connection = ActiveRecord::Base.connection
      @schema_ready[site] = connection.table_exists?(:live_rooms) &&
        connection.column_exists?(:live_rooms, :ephemeral)
    end
    private_class_method :schema_ready?
  end
end
