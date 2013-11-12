module Export

  class UnsupportedExportSource   < RuntimeError; end
  class FormatInvalidError        < RuntimeError; end
  class FilenameMissingError      < RuntimeError; end
  class ExportInProgressError     < RuntimeError; end

  def self.current_schema_version
    ActiveRecord::Migrator.current_version.to_s
  end

  def self.models_included_in_export
    @models_included_in_export ||= begin
      Rails.application.eager_load! # So that all models get loaded now
      ActiveRecord::Base.descendants - [ActiveRecord::SchemaMigration]
    end
  end

  def self.export_running_key
    'exporter_is_running'
  end

  def self.is_export_running?
    $redis.get(export_running_key) == '1'
  end

  def self.set_export_started
    $redis.set export_running_key, '1'
  end

  def self.set_export_is_not_running
    $redis.del export_running_key
  end

end