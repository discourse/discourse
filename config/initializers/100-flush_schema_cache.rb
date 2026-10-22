# frozen_string_literal: true

# Published by BackupRestore::Restorer when a restore completes: the restored
# database's custom types (enums) were recreated under new OIDs and its
# columns may differ from what every long-lived process cached in that site's
# connection pool before the restore. Only that pool is touched: class-level
# attribute types carry no OIDs, and resetting column information on every
# model from this thread would race with requests using those models.
MessageBus.subscribe("/schema_cache_flush") do |msg|
  db = msg.data

  if RailsMultisite::ConnectionManagement.all_dbs.include?(db)
    RailsMultisite::ConnectionManagement.with_connection(db) do
      ActiveRecord::Base.connection_pool.schema_cache.clear!
    end
  end
rescue => e
  Rails.logger.warn("Failed to flush schema cache for '#{db}': #{e.class} #{e.message}")
end
